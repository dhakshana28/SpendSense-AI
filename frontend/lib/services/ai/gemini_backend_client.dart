import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';

/// Raised when the SpendSense AI backend cannot satisfy a Gemini request.
///
/// Carries the HTTP status code so [GeminiService] can classify the failure
/// (quota, auth, network, ...) and apply the matching cooldown.
class GeminiBackendException implements Exception {
  GeminiBackendException({
    required this.statusCode,
    required this.userMessage,
    this.detail = '',
  });

  /// HTTP status returned by the backend, or 0 when the request never reached
  /// it (DNS / socket / timeout failure).
  final int statusCode;

  /// Short, safe message that can be shown to the user verbatim.
  final String userMessage;

  /// Raw backend detail, kept for logging only - never shown to the user.
  final String detail;

  @override
  String toString() {
    if (statusCode == 0) {
      return 'GeminiBackendException: network failure ($userMessage, detail: $detail)';
    }
    return 'GeminiBackendException($statusCode): $userMessage ($detail)';
  }
}

/// Result of probing the backend's `/health` endpoint.
class BackendHealth {
  const BackendHealth({
    required this.reachable,
    required this.geminiConfigured,
    required this.model,
  });

  /// True when the backend answered successfully.
  final bool reachable;

  /// True when the backend has a `GEMINI_API_KEY` configured server-side.
  final bool geminiConfigured;

  /// Gemini model the backend will use (empty when unknown).
  final String model;

  static const BackendHealth unreachable = BackendHealth(
    reachable: false,
    geminiConfigured: false,
    model: '',
  );
}

/// Candidate backend discovery result.
class DiscoveredBackend {
  const DiscoveredBackend({
    required this.url,
    required this.health,
  });

  final String url;
  final BackendHealth health;
}

/// Maps a backend HTTP status to the user-facing message required by the
/// task spec. Never leaks keys, stack traces, or internals.
String geminiBackendErrorMessage({required int statusCode}) {
  if (statusCode == 0) {
    return 'Could not reach the SpendSense backend. Check your network or PC server status.';
  }
  if (statusCode == 400) {
    return 'The AI could not answer that request. Please rephrase and try again.';
  }
  if (statusCode == 401 || statusCode == 403) {
    return 'Gemini API Key is not configured on the server. Please contact the app developer.';
  }
  if (statusCode == 404) {
    return 'AI endpoint or model not found on backend. Please update your app or backend.';
  }
  if (statusCode == 429) {
    return 'Gemini request limit reached. Please try again later.';
  }
  if (statusCode == 503) {
    return 'Gemini AI service is temporarily unavailable. Please try again shortly.';
  }
  if (statusCode >= 500) {
    return 'AI service is temporarily unavailable.';
  }
  return 'AI service returned an unexpected response.';
}

/// Probes `GET /health` on the backend.
///
/// This is the only way the app learns whether Gemini is usable - the API key
/// itself never leaves the server.
Future<BackendHealth> fetchBackendHealth({
  required String baseUrl,
  Duration? timeout,
}) async {
  final isRemote = baseUrl.startsWith('https://');
  final effectiveTimeout = timeout ??
      (isRemote ? const Duration(seconds: 35) : const Duration(seconds: 3));

  try {
    final uri = Uri.parse('$baseUrl/health');
    final res = await http.get(uri).timeout(effectiveTimeout);
    if (res.statusCode != 200) {
      debugPrint('[Backend Probe] $baseUrl answered with HTTP ${res.statusCode}');
      return BackendHealth.unreachable;
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return BackendHealth.unreachable;
    final health = BackendHealth(
      reachable: true,
      geminiConfigured: decoded['geminiConfigured'] == true,
      model: (decoded['model'] ?? '').toString(),
    );
    debugPrint('[Backend Probe] ✓ $baseUrl reachable (geminiConfigured: ${health.geminiConfigured}, model: ${health.model})');
    return health;
  } catch (e) {
    debugPrint('[Backend Probe] ✗ $baseUrl failed: $e');
    return BackendHealth.unreachable;
  }
}

/// Concurrently probes a list of candidate backend URLs with a fast timeout.
///
/// Prioritizes candidates that are reachable AND have `geminiConfigured == true`.
/// If none has Gemini configured, falls back to any reachable backend.
Future<DiscoveredBackend?> discoverReachableBackend({
  required List<String> candidates,
  Duration timeout = const Duration(seconds: 35),
}) async {
  if (candidates.isEmpty) return null;

  debugPrint('[Backend Discovery] Testing candidate URLs concurrently: $candidates');

  final futures = candidates.map((url) async {
    // Remote HTTPS URLs need up to 15s to tolerate possible cloud sleep / cold start;
    // local loopback / LAN should fail fast (2s) so local dev isn't delayed.
    final probeTimeout = url.startsWith('https://')
        ? timeout
        : const Duration(milliseconds: 2000);
    final h = await fetchBackendHealth(baseUrl: url, timeout: probeTimeout);
    return DiscoveredBackend(url: url, health: h);
  }).toList();

  final results = await Future.wait(futures);

  // 1. First priority: reachable AND Gemini key configured
  for (final res in results) {
    if (res.health.reachable && res.health.geminiConfigured) {
      debugPrint('[Backend Discovery] Selected live backend: ${res.url} (model: ${res.health.model})');
      return res;
    }
  }

  // 2. Second priority: reachable backend (server running, key might need check)
  for (final res in results) {
    if (res.health.reachable) {
      debugPrint('[Backend Discovery] Selected reachable backend (unconfigured key): ${res.url}');
      return res;
    }
  }

  debugPrint('[Backend Discovery] No candidate was reachable within timeout.');
  return null;
}

/// POSTs a prompt to the backend's Gemini proxy (`POST /api/ai/chat`).
///
/// The request body matches the backend `ChatRequest` model:
/// `{"prompt": str, "history": [{"role": "user"|"model", "text": str}]}`.
/// Returns the generated text from the `response` field of `ChatResponse`.
///
/// Throws [GeminiBackendException] on any non-200 response or transport error.
Future<String> sendGeminiChatRequest({
  required String baseUrl,
  required String prompt,
  List<Map<String, String>> history = const [],
  Duration timeout = const Duration(seconds: 40),
  bool allowRetry = true,
}) async {
  final uri = Uri.parse('$baseUrl/api/ai/chat');
  final isRemote = baseUrl.startsWith('https://');

  Future<http.Response> doSend() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final authKey = ApiConfig.authKey;
    if (authKey.isNotEmpty) {
      headers['X-SpendSense-Auth-Key'] = authKey;
    }

    return http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'prompt': prompt, 'history': history}),
        )
        .timeout(timeout);
  }

  http.Response res;
  try {
    res = await doSend();
  } on TimeoutException catch (e) {
    final timeoutMsg = isRemote
        ? 'The AI server is waking up from idle mode (cold start). Please try again in a few seconds.'
        : 'The request timed out. Please check your connection and try again.';
    if (allowRetry) {
      debugPrint('[Gemini Client] Request to $uri timed out. Retrying once...');
      try {
        await Future.delayed(const Duration(milliseconds: 1500));
        res = await doSend();
      } catch (retryError) {
        throw GeminiBackendException(
          statusCode: 0,
          userMessage: timeoutMsg,
          detail: 'Timeout after retry: $retryError',
        );
      }
    } else {
      throw GeminiBackendException(
        statusCode: 0,
        userMessage: timeoutMsg,
        detail: e.toString(),
      );
    }
  } catch (e) {
    if (allowRetry) {
      debugPrint('[Gemini Client] Transport error contacting $uri ($e). Retrying once...');
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        res = await doSend();
      } catch (retryError) {
        throw GeminiBackendException(
          statusCode: 0,
          userMessage: 'Could not reach the AI service. Please check your connection.',
          detail: 'Transport error contacting $baseUrl after retry: $retryError',
        );
      }
    } else {
      throw GeminiBackendException(
        statusCode: 0,
        userMessage: 'Could not reach the AI service. Please check your connection.',
        detail: 'Transport error contacting $baseUrl: $e',
      );
    }
  }

  // Handle transient 503 with a single retry if allowed
  if (res.statusCode == 503 && allowRetry) {
    debugPrint('[Gemini Client] Backend returned 503. Retrying once after 1s...');
    await Future.delayed(const Duration(seconds: 1));
    try {
      res = await doSend();
    } catch (_) {
      // Keep original 503 response if retry throws
    }
  }

  if (res.statusCode != 200) {
    final detail = _extractDetail(res.body);
    debugPrint('[Gemini Client] HTTP error ${res.statusCode} from $baseUrl: $detail');
    throw GeminiBackendException(
      statusCode: res.statusCode,
      userMessage: geminiBackendErrorMessage(statusCode: res.statusCode),
      detail: detail.isEmpty ? 'HTTP ${res.statusCode}' : detail,
    );
  }

  final text = _extractResponse(res.body);
  if (text.isEmpty) {
    throw GeminiBackendException(
      statusCode: 502,
      userMessage: geminiBackendErrorMessage(statusCode: 502),
      detail: 'Backend returned an empty "response" field.',
    );
  }
  return text;
}

/// Pulls FastAPI's `{"detail": ...}` error payload out of a response body.
String _extractDetail(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['detail'] != null) {
      return decoded['detail'].toString();
    }
  } catch (_) {}
  return '';
}

/// Pulls the generated text out of the backend `ChatResponse` body.
String _extractResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['response'] != null) {
      return decoded['response'].toString().trim();
    }
  } catch (_) {}
  return '';
}
