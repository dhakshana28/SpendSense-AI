"""SpendSense AI backend - Gemini proxy.

Keeps the Gemini API key exclusively server-side. The Flutter app calls this
backend; the backend calls Google Gemini via the official v1beta REST API.
The key is never bundled into the APK, returned to clients, or printed in logs.
"""

import asyncio
import hashlib
import logging
import os
import random
import time
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
import httpx
from pydantic import BaseModel, Field

# Load the backend .env that lives next to this file
ENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
load_dotenv(dotenv_path=ENV_PATH)

# The Gemini API key must exist ONLY here on the backend/server environment.
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()

# SpendSense Backend Authentication Key (for securing public tunnel endpoints)
BACKEND_AUTH_KEY = os.getenv("BACKEND_AUTH_KEY", "").strip()

# Default to verified active Gemini model on v1beta. Override with GEMINI_MODEL.
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip() or "gemini-2.5-flash"
GEMINI_TIMEOUT_SECONDS = float(os.getenv("GEMINI_TIMEOUT_SECONDS", "25.0"))
MAX_RETRIES = int(os.getenv("GEMINI_MAX_RETRIES", "3"))

# Rate Limiter settings (per client IP)
RATE_LIMIT_MAX_REQUESTS = int(os.getenv("RATE_LIMIT_MAX_REQUESTS", "30"))
RATE_LIMIT_WINDOW_SECONDS = float(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60.0"))

TUNNEL_INFO_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".active_tunnel_url")
STATUS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend_status.json")

log = logging.getLogger("spendsense-ai")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

from contextlib import asynccontextmanager

# Global HTTP async client with connection pooling
_http_client: Optional[httpx.AsyncClient] = None
# Request deduplication map: cache_key -> asyncio.Future
_in_flight_requests: Dict[str, asyncio.Future] = {}
_in_flight_lock = asyncio.Lock()

# Rate limit tracking: client_ip -> list of request timestamps
_client_request_history: Dict[str, List[float]] = {}
_rate_limit_lock = asyncio.Lock()


async def check_rate_limit(client_ip: str) -> bool:
    """Enforce sliding-window rate limit per client IP."""
    now = time.time()
    cutoff = now - RATE_LIMIT_WINDOW_SECONDS
    async with _rate_limit_lock:
        history = _client_request_history.get(client_ip, [])
        history = [t for t in history if t > cutoff]
        if len(history) >= RATE_LIMIT_MAX_REQUESTS:
            _client_request_history[client_ip] = history
            return False
        history.append(now)
        _client_request_history[client_ip] = history
        return True


def verify_auth(request: Request):
    """Enforce backend auth key when BACKEND_AUTH_KEY is configured.
    
    Accepts X-SpendSense-Auth-Key header, X-API-Key header, or Bearer token.
    """
    if not BACKEND_AUTH_KEY:
        return

    token = request.headers.get("x-spendsense-auth-key") or request.headers.get("x-api-key")
    if not token:
        auth_header = request.headers.get("authorization", "")
        if auth_header.lower().startswith("bearer "):
            token = auth_header[7:].strip()

    if not token or token != BACKEND_AUTH_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing SpendSense backend authentication key.",
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _http_client
    _http_client = httpx.AsyncClient(
        timeout=httpx.Timeout(GEMINI_TIMEOUT_SECONDS, connect=10.0),
        limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
    )
    if not GEMINI_API_KEY:
        log.warning(
            "GEMINI_API_KEY is NOT set. Gemini AI calls will return 503 until a valid key is provided in backend/.env"
        )
    else:
        # Safe log: never log the key itself, only that it is loaded with its length
        log.info(
            "Backend initialized. GEMINI_API_KEY is configured (length: %d). Model: %s. Auth: %s",
            len(GEMINI_API_KEY),
            GEMINI_MODEL,
            "Enabled" if BACKEND_AUTH_KEY else "Disabled",
        )
    yield
    if _http_client is not None:
        await _http_client.aclose()


app = FastAPI(
    title="SpendSense AI Backend",
    version="1.2.0",
    description="Secure, resilient backend proxy for Gemini AI in SpendSense AI",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def sanitize_logging_middleware(request: Request, call_next):
    """Safe, sanitized request logging middleware that prevents leaks."""
    start_time = time.time()
    client_ip = request.client.host if request.client else "unknown"
    ip_parts = client_ip.split(".")
    masked_ip = f"{ip_parts[0]}.{ip_parts[1]}.***.***" if len(ip_parts) == 4 else client_ip[:8]

    path = request.url.path
    method = request.method

    response = await call_next(request)
    duration_ms = (time.time() - start_time) * 1000

    # Never log auth headers, prompt contents, or financial data
    log.info("%s %s -> HTTP %d (%.1fms) [from %s]", method, path, response.status_code, duration_ms, masked_ip)
    return response


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class ChatHistoryTurn(BaseModel):
    role: str = "user"
    text: Optional[str] = None
    parts: Optional[List[Any]] = None


class ChatRequest(BaseModel):
    prompt: str = Field(default="", description="The user prompt or query")
    message: str = Field(default="", description="Alternative alias for prompt")
    history: List[Dict[str, Any]] = Field(default_factory=list, description="Recent conversation turns")
    system_prompt: str = Field(default="", description="Optional system instruction")

    def get_effective_prompt(self) -> str:
        text = self.prompt.strip() if self.prompt else self.message.strip()
        return text


class ChatResponse(BaseModel):
    response: str
    error: str = ""
    model: str = GEMINI_MODEL
    status: str = "ok"
    is_fallback: bool = False


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/")
@app.get("/health")
@app.get("/api/health")
@app.get("/api/ai/health")
def health():
    """Health check endpoint distinguishing backend availability from Gemini key configuration."""
    return {
        "status": "ok",
        "geminiConfigured": bool(GEMINI_API_KEY),
        "authConfigured": bool(BACKEND_AUTH_KEY),
        "model": GEMINI_MODEL,
        "version": "1.2.0",
    }


@app.get("/api/ai/model")
def get_model():
    return {
        "model": GEMINI_MODEL,
        "configured": bool(GEMINI_API_KEY),
        "authConfigured": bool(BACKEND_AUTH_KEY),
    }


@app.get("/api/tunnel-info")
def get_tunnel_info():
    """Returns the current active public tunnel URL and server metadata.
    
    Used by the SpendSense AI Flutter app for automatic 1-tap discovery over LAN.
    """
    public_url = ""
    if os.path.exists(TUNNEL_INFO_FILE):
        try:
            with open(TUNNEL_INFO_FILE, "r", encoding="utf-8") as f:
                public_url = f.read().strip()
        except Exception:
            pass
    if not public_url:
        public_url = os.getenv("BACKEND_PUBLIC_URL", "").strip()

    return {
        "status": "ok",
        "publicUrl": public_url,
        "authConfigured": bool(BACKEND_AUTH_KEY),
        "geminiConfigured": bool(GEMINI_API_KEY),
        "model": GEMINI_MODEL,
        "version": "1.2.0",
        "timestamp": time.time(),
    }


@app.get("/api/test-gemini")
@app.get("/api/ai/health/deep")
async def test_gemini(request: Request):
    """Live connectivity health check: verifies communication with Google Gemini without exposing secrets."""
    verify_auth(request)
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Gemini API Key is not configured on the server. Please check backend/.env.",
        )
    try:
        text, used_model = await _call_gemini_with_resilience("Reply with 'OK'.", [])
        return {
            "status": "ok",
            "geminiLive": True,
            "model": used_model,
            "response": text,
        }
    except HTTPException as e:
        log.error("Deep health check HTTP error: %s", e.detail)
        return {
            "status": "error",
            "geminiLive": False,
            "statusCode": e.status_code,
            "error": e.detail,
        }
    except Exception as e:
        log.error("Deep health check unexpected error: %s", e)
        return {
            "status": "error",
            "geminiLive": False,
            "statusCode": 502,
            "error": "Failed to connect to Gemini AI.",
        }


@app.post("/api/ai/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, request: Request):
    """Forward a prompt (with optional history) to Gemini with retry, backoff, deduplication, and auth."""
    # 1. Enforce authentication on public chat endpoint
    verify_auth(request)

    # 2. Rate limit check per client IP
    client_ip = request.client.host if request.client else "unknown"
    allowed = await check_rate_limit(client_ip)
    if not allowed:
        log.warning("Rate limit exceeded for client IP %s", client_ip)
        raise HTTPException(
            status_code=429,
            detail="Request limit reached. Please wait a moment before sending more AI requests.",
            headers={"Retry-After": "60"},
        )

    # 3. Validate prompt
    prompt = req.get_effective_prompt()
    if not prompt:
        raise HTTPException(status_code=400, detail="Prompt must not be empty.")

    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Gemini API Key is not configured on the server. Please check backend API configuration.",
        )

    # In-flight deduplication: prevent duplicate concurrent identical requests
    req_hash = hashlib.sha256(
        f"{prompt[:500]}|{len(req.history)}".encode("utf-8")
    ).hexdigest()

    async with _in_flight_lock:
        if req_hash in _in_flight_requests:
            future = _in_flight_requests[req_hash]
            log.info("Deduplicating concurrent request for hash %s...", req_hash[:8])
        else:
            loop = asyncio.get_running_loop()
            future = loop.create_future()
            _in_flight_requests[req_hash] = future
            # Spawn worker to resolve future
            asyncio.create_task(_execute_chat_request(req_hash, prompt, req.history, future))

    try:
        text, used_model = await future
        return ChatResponse(
            response=text,
            model=used_model,
            status="ok",
            is_fallback=False,
        )
    except HTTPException:
        raise
    except Exception as e:
        log.error("Unexpected error in chat endpoint: %s", e)
        raise HTTPException(
            status_code=502,
            detail="AI service returned an unexpected response.",
        )


async def _execute_chat_request(
    req_hash: str,
    prompt: str,
    history: List[Dict[str, Any]],
    future: asyncio.Future,
):
    try:
        result = await _call_gemini_with_resilience(prompt, history)
        if not future.done():
            future.set_result(result)
    except Exception as exc:
        if not future.done():
            future.set_exception(exc)
    finally:
        async with _in_flight_lock:
            _in_flight_requests.pop(req_hash, None)


# Legacy alias
@app.post("/api/chat", response_model=ChatResponse)
async def chat_legacy(req: ChatRequest, request: Request):
    return await chat(req, request)


# ---------------------------------------------------------------------------
# Gemini API Calling Logic with Resilience
# ---------------------------------------------------------------------------

def _build_contents(prompt: str, history: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Builds clean contents payload from history turns and the current prompt."""
    contents: List[Dict[str, Any]] = []
    # Cap history to last 4 turns to keep requests lean and fast
    for turn in (history or [])[-4:]:
        role = turn.get("role", "user")
        if role not in ("user", "model"):
            role = "user"
        text = turn.get("text", "")
        if not text and isinstance(turn.get("parts"), list) and turn["parts"]:
            first_part = turn["parts"][0]
            if isinstance(first_part, dict):
                text = str(first_part.get("text", ""))
            else:
                text = str(first_part)
        if text:
            contents.append({
                "role": role,
                "parts": [{"text": str(text)[:800]}],
            })

    contents.append({
        "role": "user",
        "parts": [{"text": prompt[:2500]}],
    })
    return contents


async def _call_gemini_with_resilience(
    prompt: str,
    history: List[Dict[str, Any]],
) -> tuple[str, str]:
    """Call Google Gemini with bounded retries, exponential backoff, jitter, and model failover.

    Returns tuple of (generated_text, model_used).
    Raises HTTPException with proper status code on failure.
    """
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            timeout=httpx.Timeout(GEMINI_TIMEOUT_SECONDS, connect=10.0),
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
        )

    contents = _build_contents(prompt, history)
    body = {
        "contents": contents,
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1024,
        },
    }

    # Model candidates: configured model first, followed by verified stable models
    models_to_try = [
        GEMINI_MODEL,
        "gemini-2.5-flash",
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-2.5-pro",
    ]
    seen_models: List[str] = []
    for m in models_to_try:
        if m and m not in seen_models:
            seen_models.append(m)

    last_error_code = 503
    last_error_detail = "AI service is temporarily unavailable."

    for model in seen_models:
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/"
            f"models/{model}:generateContent"
        )
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": GEMINI_API_KEY,
        }

        # Bounded retries for transient failures per model
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                resp = await _http_client.post(url, json=body, headers=headers)
                
                # Check for successful response
                if resp.status_code == 200:
                    data = resp.json()
                    candidates = data.get("candidates", [])
                    if not candidates:
                        feedback = data.get("promptFeedback", {})
                        if feedback.get("blockReason"):
                            raise HTTPException(
                                status_code=400,
                                detail=f"AI request was blocked by safety settings: {feedback.get('blockReason')}",
                            )
                        raise HTTPException(
                            status_code=502,
                            detail="AI service returned an unexpected empty response.",
                        )
                    
                    candidate = candidates[0]
                    content_parts = candidate.get("content", {}).get("parts", [])
                    if not content_parts or not content_parts[0].get("text"):
                        raise HTTPException(
                            status_code=502,
                            detail="AI service returned an unexpected content structure.",
                        )
                    
                    text = content_parts[0]["text"].strip()
                    if not text:
                        raise HTTPException(
                            status_code=502,
                            detail="AI service returned an empty response.",
                        )
                    return text, model

                # Handle HTTP errors
                status_code = resp.status_code
                try:
                    err_json = resp.json().get("error", {})
                    err_msg = err_json.get("message", resp.text[:200])
                    err_status = err_json.get("status", "")
                except Exception:
                    err_msg = resp.text[:200]
                    err_status = ""

                log.warning(
                    "Gemini API returned %d for model %s (attempt %d/%d): %s",
                    status_code,
                    model,
                    attempt,
                    MAX_RETRIES,
                    err_msg,
                )

                # Permanent failure: Bad API Key or Auth
                if status_code in (401, 403):
                    log.error("Permanent authentication failure with Gemini: %s", err_msg)
                    raise HTTPException(
                        status_code=401,
                        detail="Gemini authentication failed. Check the backend API configuration.",
                    )

                # Permanent failure: Bad Request / Safety / Prompt syntax
                if status_code == 400:
                    if "API_KEY_INVALID" in err_msg or "API key not valid" in err_msg:
                        raise HTTPException(
                            status_code=401,
                            detail="Gemini API Key is invalid. Check the backend API configuration.",
                        )
                    log.error("Gemini 400 Bad Request (model %s): %s", model, err_msg)
                    raise HTTPException(
                        status_code=400,
                        detail="Invalid Gemini request or prompt. Please verify input.",
                    )

                # Model not found or retired (404) -> switch to next model immediately
                if status_code == 404:
                    log.info("Model %s returned 404, attempting fallback model...", model)
                    last_error_code = 404
                    last_error_detail = f"Model {model} was not found."
                    break  # Break attempt loop, try next model

                # Rate Limit / Quota Exceeded (429)
                if status_code == 429:
                    last_error_code = 429
                    last_error_detail = "Gemini request limit reached. Please try again later."
                    if attempt < MAX_RETRIES:
                        # Check Retry-After header
                        retry_after_hdr = resp.headers.get("retry-after")
                        backoff = 1.0 * (2 ** (attempt - 1)) + random.uniform(0.1, 0.5)
                        if retry_after_hdr:
                            try:
                                backoff = max(backoff, min(float(retry_after_hdr), 8.0))
                            except ValueError:
                                pass
                        log.info("Rate limit 429 hit; backing off for %.2fs before retry...", backoff)
                        await asyncio.sleep(backoff)
                        continue
                    else:
                        log.warning("Max retries exceeded for 429 on model %s, trying next model", model)
                        break

                # Server Error (5xx)
                if status_code >= 500:
                    last_error_code = 503
                    last_error_detail = "AI service is temporarily unavailable."
                    if attempt < MAX_RETRIES:
                        backoff = 1.0 * (2 ** (attempt - 1)) + random.uniform(0.1, 0.5)
                        log.info("Server error %d hit; backing off for %.2fs before retry...", status_code, backoff)
                        await asyncio.sleep(backoff)
                        continue
                    else:
                        break

            except (httpx.TimeoutException, httpx.NetworkError) as net_err:
                log.warning(
                    "Network/timeout error talking to Gemini on model %s (attempt %d/%d): %s",
                    model,
                    attempt,
                    MAX_RETRIES,
                    net_err,
                )
                last_error_code = 504
                last_error_detail = "Gemini request timed out. Please try again."
                if attempt < MAX_RETRIES:
                    backoff = 1.0 * (2 ** (attempt - 1)) + random.uniform(0.1, 0.5)
                    await asyncio.sleep(backoff)
                    continue
                else:
                    break

    # If all models and retries were exhausted
    log.error("All Gemini models exhausted. Returning status %d: %s", last_error_code, last_error_detail)
    raise HTTPException(status_code=last_error_code, detail=last_error_detail)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
