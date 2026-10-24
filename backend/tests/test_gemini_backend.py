"""Tests for SpendSense AI Gemini backend proxy.

Covers:
- /health and /api/health endpoints
- Startup validation and missing API key handling
- Empty prompt validation (400)
- Upstream HTTP error classification (401, 403, 429, 503)
- Retries with backoff on transient errors
- Live end-to-end call to Google Gemini (when key is available)
"""

import os
import pytest
from httpx import AsyncClient, Response
from fastapi.testclient import TestClient

import main
from main import app


@pytest.fixture
def auth_headers():
    if main.BACKEND_AUTH_KEY:
        return {"X-SpendSense-Auth-Key": main.BACKEND_AUTH_KEY}
    return {}


@pytest.fixture
def client(auth_headers):
    with TestClient(app, headers=auth_headers) as test_client:
        yield test_client


def test_health_endpoint(client):
    """Health check reports backend status, configured state, and model."""
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert "geminiConfigured" in data
    assert "authConfigured" in data
    assert "model" in data
    assert data["model"] != ""


def test_tunnel_info_endpoint(client, tmp_path, monkeypatch):
    """Tunnel info endpoint returns status, publicUrl, and config flags."""
    test_file = tmp_path / ".active_tunnel_url"
    test_file.write_text("https://test-active-tunnel.trycloudflare.com")
    monkeypatch.setattr(main, "TUNNEL_INFO_FILE", str(test_file))

    res = client.get("/api/tunnel-info")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert data["publicUrl"] == "https://test-active-tunnel.trycloudflare.com"
    assert data["authConfigured"] is True


def test_auth_rejection_without_key():
    """Unauthenticated call to /api/ai/chat returns 401 when auth is configured."""
    with TestClient(app) as unauth_client:
        res = unauth_client.post("/api/ai/chat", json={"prompt": "Hello"})
        if main.BACKEND_AUTH_KEY:
            assert res.status_code == 401
            assert "authentication" in res.json()["detail"].lower()


def test_auth_rejection_with_invalid_key():
    """Call to /api/ai/chat with wrong auth key returns 401."""
    with TestClient(app, headers={"X-SpendSense-Auth-Key": "wrong_key"}) as bad_client:
        res = bad_client.post("/api/ai/chat", json={"prompt": "Hello"})
        if main.BACKEND_AUTH_KEY:
            assert res.status_code == 401
            assert "authentication" in res.json()["detail"].lower()


def test_rate_limiting(client, monkeypatch):
    """Rate limiter returns 429 when max requests threshold is exceeded."""
    monkeypatch.setattr(main, "RATE_LIMIT_MAX_REQUESTS", 2)
    # Clear client history for clean test
    main._client_request_history.clear()

    # Fast mock for gemini call
    async def mock_call(prompt, history):
        return "OK", "test-model"

    monkeypatch.setattr(main, "_call_gemini_with_resilience", mock_call)
    monkeypatch.setattr(main, "GEMINI_API_KEY", "test-key")

    res1 = client.post("/api/ai/chat", json={"prompt": "One"})
    assert res1.status_code == 200

    res2 = client.post("/api/ai/chat", json={"prompt": "Two"})
    assert res2.status_code == 200

    # Third request exceeds limit
    res3 = client.post("/api/ai/chat", json={"prompt": "Three"})
    assert res3.status_code == 429
    assert "limit" in res3.json()["detail"].lower()
    assert "Retry-After" in res3.headers

    # Reset limit
    monkeypatch.setattr(main, "RATE_LIMIT_MAX_REQUESTS", 30)
    main._client_request_history.clear()


def test_api_ai_health_endpoint(client):
    """Alternate health endpoints match /health."""
    res = client.get("/api/ai/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert "geminiConfigured" in data


def test_empty_prompt_returns_400(client):
    """Empty or whitespace-only prompt returns 400 Bad Request."""
    res = client.post("/api/ai/chat", json={"prompt": "   "})
    assert res.status_code == 400
    assert "empty" in res.json()["detail"].lower()


def test_message_alias_supported(client, monkeypatch):
    """ChatRequest accepts 'message' as an alias for 'prompt'."""
    # Mock _call_gemini_with_resilience to avoid external call
    async def mock_call(prompt, history):
        return f"Echo: {prompt}", "test-model"

    monkeypatch.setattr(main, "_call_gemini_with_resilience", mock_call)
    monkeypatch.setattr(main, "GEMINI_API_KEY", "test-key")

    res = client.post("/api/ai/chat", json={"message": "Hello from Flutter"})
    assert res.status_code == 200
    assert res.json()["response"] == "Echo: Hello from Flutter"


def test_missing_api_key_returns_503(client, monkeypatch):
    """When GEMINI_API_KEY is unset or empty, /api/ai/chat returns 503."""
    monkeypatch.setattr(main, "GEMINI_API_KEY", "")
    res = client.post("/api/ai/chat", json={"prompt": "Hello"})
    assert res.status_code == 503
    assert "configured" in res.json()["detail"].lower() or "unavailable" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_upstream_401_fails_immediately_without_useless_retries(monkeypatch):
    """Upstream 401 Unauthorized raises 401 and stops immediately."""
    call_count = 0

    async def mock_post(url, json=None, headers=None):
        nonlocal call_count
        call_count += 1
        return Response(
            status_code=401,
            json={"error": {"code": 401, "message": "API key not valid. Please pass a valid API key."}},
        )

    class MockHttpClient:
        is_closed = False
        async def post(self, url, json=None, headers=None):
            return await mock_post(url, json=json, headers=headers)

    monkeypatch.setattr(main, "_http_client", MockHttpClient())
    monkeypatch.setattr(main, "GEMINI_API_KEY", "invalid_key")

    with pytest.raises(main.HTTPException) as exc_info:
        await main._call_gemini_with_resilience("Hello", [])

    assert exc_info.value.status_code == 401
    # Permanent failure should not burn multiple retry attempts
    assert call_count == 1


@pytest.mark.asyncio
async def test_upstream_429_backs_off_and_retries(monkeypatch):
    """Upstream 429 retries with backoff and succeeds if subsequent attempt succeeds."""
    attempt = 0

    async def mock_post(url, json=None, headers=None):
        nonlocal attempt
        attempt += 1
        if attempt == 1:
            return Response(
                status_code=429,
                headers={"retry-after": "0.1"},
                json={"error": {"code": 429, "message": "Resource has been exhausted"}},
            )
        return Response(
            status_code=200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [{"text": "Success after backoff"}]
                        }
                    }
                ]
            },
        )

    class MockHttpClient:
        is_closed = False
        async def post(self, url, json=None, headers=None):
            return await mock_post(url, json=json, headers=headers)

    monkeypatch.setattr(main, "_http_client", MockHttpClient())
    monkeypatch.setattr(main, "GEMINI_API_KEY", "test-key")

    text, model = await main._call_gemini_with_resilience("Hello", [])
    assert text == "Success after backoff"
    assert attempt == 2


@pytest.mark.asyncio
async def test_live_gemini_integration():
    """Live integration test: hits Google Gemini directly through backend if valid key is set."""
    if not main.GEMINI_API_KEY or "your_" in main.GEMINI_API_KEY.lower():
        pytest.skip("No valid live GEMINI_API_KEY found in backend/.env")

    # Real call to Gemini with a basic prompt
    text, model = await main._call_gemini_with_resilience(
        "Give a 1-sentence tip on monthly savings.",
        [],
    )
    assert text is not None and len(text.strip()) > 5
    assert model in ["gemini-2.5-flash", "gemini-3.5-flash-lite", "gemini-flash-latest", "gemini-2.5-pro"]
    print(f"\n[LIVE TEST SUCCESS] Gemini responded via model {model}: {text[:80]}...")
