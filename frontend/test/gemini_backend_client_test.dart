import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/ai/gemini_backend_client.dart';
import 'package:frontend/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spins up a real loopback HTTP server so the client exercises actual
/// sockets, headers and JSON encoding instead of a mocked transport.
///
/// Keeping this honest matters: the whole point of the backend proxy is that
/// the app talks HTTP to FastAPI, so the contract under test is the wire
/// format (`POST /api/ai/chat` <- {"prompt", "history"}).
class _TestBackend {
  _TestBackend(this._respond, {this.delay = Duration.zero});

  final ({int status, String body}) Function() _respond;
  final Duration delay;

  late final HttpServer _server;

  /// Paths requested, in order.
  final List<String> paths = [];

  /// JSON-decoded request bodies, in order (null when the body was empty).
  final List<Map<String, dynamic>?> bodies = [];

  /// HTTP methods used, in order.
  final List<String> methods = [];

  /// Inbound HTTP request headers, in order.
  final List<Map<String, String>> recordedHeaders = [];

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      paths.add(req.uri.path);
      methods.add(req.method);
      final headerMap = <String, String>{};
      req.headers.forEach((name, values) {
        headerMap[name.toLowerCase()] = values.join(', ');
      });
      recordedHeaders.add(headerMap);
      final raw = await utf8.decoder.bind(req).join();
      bodies.add(raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>);

      if (delay > Duration.zero) await Future<void>.delayed(delay);

      final res = _respond();
      req.response
        ..statusCode = res.status
        ..headers.contentType = ContentType.json
        ..write(res.body);
      await req.response.close();
    });
    return 'http://127.0.0.1:${_server.port}';
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

/// Binds a port and immediately releases it, guaranteeing "connection refused".
Future<String> _closedBaseUrl() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close(force: true);
  return 'http://127.0.0.1:$port';
}

void main() {
  group('sendGeminiChatRequest', () {
    test('POSTs {prompt, history} to /api/ai/chat and returns the text',
        () async {
      final backend = _TestBackend(
        () => (
          status: 200,
          body: jsonEncode({
            'response': 'OK',
            'error': '',
            'model': 'gemini-3.6-flash',
            'status': 'ok',
          }),
        ),
      );
      final baseUrl = await backend.start();

      final text = await sendGeminiChatRequest(
        baseUrl: baseUrl,
        prompt: 'How much did I spend?',
        history: [
          {'role': 'user', 'text': 'hi'},
          {'role': 'model', 'text': 'Hello!'},
        ],
      );

      expect(text, 'OK');
      expect(backend.paths.single, '/api/ai/chat');
      expect(backend.methods.single, 'POST');
      // Exact wire contract expected by backend `ChatRequest`.
      expect(backend.bodies.single, {
        'prompt': 'How much did I spend?',
        'history': [
          {'role': 'user', 'text': 'hi'},
          {'role': 'model', 'text': 'Hello!'},
        ],
      });

      await backend.stop();
    });

    test('omits history as an empty list when none is supplied', () async {
      final backend = _TestBackend(
        () => (status: 200, body: jsonEncode({'response': 'hi'})),
      );
      final baseUrl = await backend.start();

      await sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'hello');

      expect(backend.bodies.single!['prompt'], 'hello');
      expect(backend.bodies.single!['history'], isEmpty);

      await backend.stop();
    });

    test('trims surrounding whitespace from the returned text', () async {
      final backend = _TestBackend(
        () => (status: 200, body: jsonEncode({'response': '  OK\n  '})),
      );
      final baseUrl = await backend.start();

      expect(await sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x'), 'OK');

      await backend.stop();
    });

    test('maps 429 to the rate-limit message, keeping detail for logs',
        () async {
      final backend = _TestBackend(
        () => (status: 429, body: jsonEncode({'detail': 'Quota exceeded'})),
      );
      final baseUrl = await backend.start();

      try {
        await sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x');
        fail('expected a GeminiBackendException');
      } on GeminiBackendException catch (ex) {
        expect(ex.statusCode, 429);
        expect(
          ex.userMessage,
          'Gemini request limit reached. Please try again later.',
        );
        expect(ex.detail, 'Quota exceeded');
        // The raw backend detail must never be shown to the user.
        expect(ex.userMessage.contains('Quota exceeded'), isFalse);
      }

      await backend.stop();
    });
    test('maps 401 to the server-side key message', () async {
      final backend = _TestBackend(
        () => (status: 401, body: jsonEncode({'detail': 'bad key'})),
      );
      final baseUrl = await backend.start();

      await expectLater(
        sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x'),
        throwsA(
          isA<GeminiBackendException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'Gemini API Key is not configured on the server. '
                    'Please contact the app developer.',
              ),
        ),
      );

      await backend.stop();
    });

    test('maps 502 from an upstream Gemini failure to service unavailable',
        () async {
      final backend = _TestBackend(
        () => (
          status: 502,
          body: jsonEncode(
            {'detail': 'AI service returned an unexpected response.'},
          ),
        ),
      );
      final baseUrl = await backend.start();

      await expectLater(
        sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x'),
        throwsA(
          isA<GeminiBackendException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'AI service is temporarily unavailable.',
              ),
        ),
      );

      await backend.stop();
    });

    test('rejects a 200 whose response field is blank', () async {
      final backend = _TestBackend(
        () => (status: 200, body: jsonEncode({'response': '   '})),
      );
      final baseUrl = await backend.start();

      await expectLater(
        sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x'),
        throwsA(
          isA<GeminiBackendException>()
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );

      await backend.stop();
    });

    test('reports an unreachable backend as statusCode 0, not an HTTP error',
        () async {
      final baseUrl = await _closedBaseUrl();

      await expectLater(
        sendGeminiChatRequest(baseUrl: baseUrl, prompt: 'x'),
        throwsA(
          isA<GeminiBackendException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'Could not reach the AI service. Please check your connection.',
              ),
        ),
      );
    });

    test('reports a slow backend as a timeout with statusCode 0', () async {
      final backend = _TestBackend(
        () => (status: 200, body: jsonEncode({'response': 'late'})),
        delay: const Duration(milliseconds: 400),
      );
      final baseUrl = await backend.start();

      await expectLater(
        sendGeminiChatRequest(
          baseUrl: baseUrl,
          prompt: 'x',
          timeout: const Duration(milliseconds: 80),
        ),
        throwsA(
          isA<GeminiBackendException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'The request timed out. Please check your connection and '
                    'try again.',
              ),
        ),
      );

      await backend.stop();
    });
  });
  group('fetchBackendHealth', () {
    test('reads geminiConfigured + model from GET /health', () async {
      final backend = _TestBackend(
        () => (
          status: 200,
          body: jsonEncode({
            'status': 'ok',
            'geminiConfigured': true,
            'model': 'gemini-3.6-flash',
          }),
        ),
      );
      final baseUrl = await backend.start();

      final health = await fetchBackendHealth(baseUrl: baseUrl);

      expect(backend.paths.single, '/health');
      expect(backend.methods.single, 'GET');
      expect(health.reachable, isTrue);
      expect(health.geminiConfigured, isTrue);
      expect(health.model, 'gemini-3.6-flash');

      await backend.stop();
    });

    test('reports reachable but not configured when the server has no key',
        () async {
      final backend = _TestBackend(
        () => (
          status: 200,
          body: jsonEncode({
            'status': 'ok',
            'geminiConfigured': false,
            'model': 'gemini-3.6-flash',
          }),
        ),
      );
      final baseUrl = await backend.start();

      final health = await fetchBackendHealth(baseUrl: baseUrl);

      expect(health.reachable, isTrue);
      expect(health.geminiConfigured, isFalse);

      await backend.stop();
    });

    test('treats a non-200 as unreachable', () async {
      final backend = _TestBackend(() => (status: 500, body: 'boom'));
      final baseUrl = await backend.start();

      final health = await fetchBackendHealth(baseUrl: baseUrl);

      expect(health.reachable, isFalse);
      expect(health.geminiConfigured, isFalse);
      expect(health.model, isEmpty);

      await backend.stop();
    });

    test('treats a non-JSON body as unreachable', () async {
      final backend = _TestBackend(
        () => (status: 200, body: '<html>not json</html>'),
      );
      final baseUrl = await backend.start();

      final health = await fetchBackendHealth(baseUrl: baseUrl);

      expect(health.reachable, isFalse);

      await backend.stop();
    });

    test('treats an unreachable host as unreachable', () async {
      final baseUrl = await _closedBaseUrl();

      final health = await fetchBackendHealth(baseUrl: baseUrl);

      expect(health.reachable, isFalse);
      expect(health.model, isEmpty);
    });
  });

  group('geminiBackendErrorMessage', () {
    test('always returns a user-safe sentence and never leaks internals', () {
      for (final status in [0, 400, 401, 403, 404, 429, 500, 502, 503, 999]) {
        final message = geminiBackendErrorMessage(statusCode: status);
        expect(message, isNotEmpty, reason: 'status $status');
        expect(message.endsWith('.'), isTrue, reason: 'status $status');
        expect(
          message.toLowerCase().contains('exception'),
          isFalse,
          reason: 'status $status',
        );
        expect(message.contains('AIza'), isFalse, reason: 'status $status');
      }
    });

    test('distinguishes the documented status families', () {
      expect(
        geminiBackendErrorMessage(statusCode: 400),
        'The AI could not answer that request. Please rephrase and try again.',
      );
      expect(
        geminiBackendErrorMessage(statusCode: 403),
        contains('not configured'),
      );
      expect(
        geminiBackendErrorMessage(statusCode: 429),
        contains('limit reached'),
      );
      expect(
        geminiBackendErrorMessage(statusCode: 503),
        contains('temporarily unavailable'),
      );
      expect(
        geminiBackendErrorMessage(statusCode: 418),
        contains('unexpected response'),
      );
    });
  });

  group('ApiConfig & Backend Authentication', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiConfig.setCustomBaseUrlSync(null);
      dotenv.testLoad(fileInput: 'BACKEND_PUBLIC_URL=https://spendsense-pc-tunnel.example.com\nBACKEND_AUTH_KEY=ss_key_8e4f9b2d1c6a7e305928416d8a7c2e0b\n');
    });

    test('transmits X-SpendSense-Auth-Key header with the configured auth key', () async {
      final backend = _TestBackend(
        () => (status: 200, body: jsonEncode({'response': 'Auth OK'})),
      );
      final baseUrl = await backend.start();

      await ApiConfig.setCustomAuthKey('test_secure_token_abc123');

      final res = await sendGeminiChatRequest(
        baseUrl: baseUrl,
        prompt: 'test prompt',
      );

      expect(res, 'Auth OK');
      expect(backend.recordedHeaders.single['x-spendsense-auth-key'], 'test_secure_token_abc123');

      await ApiConfig.setCustomAuthKey(null);
      await backend.stop();
    });

    test('persists custom auth key in SharedPreferences and loads it correctly', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiConfig.setCustomAuthKey('my_custom_secret_key');
      expect(ApiConfig.authKey, 'my_custom_secret_key');

      // Reset in-memory override and verify it reloads from persistent prefs
      await ApiConfig.loadSavedUrl();
      expect(ApiConfig.authKey, 'my_custom_secret_key');

      // Clear key and verify restoration to default
      await ApiConfig.setCustomAuthKey(null);
      expect(ApiConfig.authKey, ApiConfig.defaultProductionAuthKey);
    });

    test('prioritizes remote HTTPS public backend over local development loopbacks', () {
      final candidates = ApiConfig.candidateBaseUrls;
      expect(candidates, isNotEmpty);
      expect(candidates.first, startsWith('https://'));
    });
  });
}



