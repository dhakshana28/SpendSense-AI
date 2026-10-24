import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/expense_model.dart';
import 'package:frontend/models/income_model.dart';
import 'package:frontend/providers/ai_provider.dart';
import 'package:frontend/services/ai/gemini_service.dart';
import 'package:frontend/services/api_config.dart';

class _MockBackendServer {
  late final HttpServer _server;
  int statusCode = 200;
  Map<String, dynamic> responseBody = {
    'response': 'Save 20% of your income into high-yield savings.',
    'status': 'ok',
    'model': 'gemini-2.5-flash',
  };
  bool geminiConfigured = true;

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      if (req.uri.path == '/health' || req.uri.path == '/api/health') {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'status': 'ok',
            'geminiConfigured': geminiConfigured,
            'model': 'gemini-2.5-flash',
          }));
        await req.response.close();
        return;
      }

      if (req.uri.path == '/api/ai/chat') {
        req.response
          ..statusCode = statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(responseBody));
        await req.response.close();
        return;
      }

      req.response
        ..statusCode = 404
        ..write('Not found');
      await req.response.close();
    });
    return 'http://127.0.0.1:${_server.port}';
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

class _AllowAllHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _AllowAllHttpOverrides();
    dotenv.testLoad(fileInput: '');
  });

  group('ApiConfig candidate resolution', () {
    test('trims trailing slashes cleanly', () {
      expect(ApiConfig.trimTrailingSlash('http://localhost:8000/'), 'http://localhost:8000');
      expect(ApiConfig.trimTrailingSlash('http://10.0.2.2:8000///'), 'http://10.0.2.2:8000');
    });

    test('setActiveBaseUrl changes baseUrl', () {
      ApiConfig.setActiveBaseUrl('http://192.168.1.100:8000/');
      expect(ApiConfig.baseUrl, 'http://192.168.1.100:8000');
    });
  });

  group('GeminiService Resilience & Fallback Handling', () {
    late _MockBackendServer mockBackend;
    late String backendUrl;

    setUp(() async {
      mockBackend = _MockBackendServer();
      backendUrl = await mockBackend.start();
      ApiConfig.setActiveBaseUrl(backendUrl);
      GeminiService.resetCooldown();
    });

    tearDown(() async {
      await mockBackend.stop();
    });

    test('initialize establishes connection and reports model', () async {
      await GeminiService.initialize(force: true);
      expect(GeminiService.canAttemptRequest, isTrue);
      expect(GeminiService.currentModelName, 'gemini-2.5-flash');
    });

    test('generateSavingsSuggestions returns genuine AI response on 200', () async {
      mockBackend.responseBody = {
        'response': 'Cut down on dining out to save Rs. 3000 monthly.',
        'status': 'ok',
        'model': 'gemini-2.5-flash',
      };
      await GeminiService.initialize(force: true);

      final res = await GeminiService.generateSavingsSuggestions(
        incomes: [
          IncomeModel(
            id: '1',
            userId: 'u1',
            amount: 50000,
            category: 'Salary',
            source: 'Bank',
            description: 'Monthly Salary',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        expenses: [
          ExpenseModel(
            id: '1',
            userId: 'u1',
            amount: 15000,
            category: 'Food',
            paymentMethod: 'UPI',
            description: 'Grocery',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        budgets: [],
        goals: [],
      );

      expect(res.isFromFallback, isFalse);
      expect(res.content, contains('dining out'));
    });

    test('generateSavingsSuggestions marks fallback when backend returns 502', () async {
      mockBackend.statusCode = 502;
      mockBackend.responseBody = {'detail': 'AI service is temporarily unavailable.'};
      await GeminiService.initialize(force: true);

      final res = await GeminiService.generateSavingsSuggestions(
        incomes: [],
        expenses: [],
        budgets: [],
        goals: [],
      );

      expect(res.isFromFallback, isTrue);
      expect(res.errorMessage, isNotEmpty);
    });

    test('AIProvider correctly tracks isInsightFromGemini flag', () async {
      final aiProvider = AIProvider();
      mockBackend.responseBody = {
        'response': 'Real Gemini recommendation: Build a 3-month emergency fund.',
        'status': 'ok',
        'model': 'gemini-2.5-flash',
      };
      await GeminiService.initialize(force: true);

      await aiProvider.generateGeminiInsights(
        incomes: [
          IncomeModel(
            id: '1',
            userId: 'u1',
            amount: 40000,
            category: 'Salary',
            source: 'Bank',
            description: 'Salary',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        expenses: [
          ExpenseModel(
            id: '1',
            userId: 'u1',
            amount: 12000,
            category: 'Rent',
            paymentMethod: 'Bank Transfer',
            description: 'House rent',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        budgets: [],
        goals: [],
      );

      expect(aiProvider.isInsightFromGemini, isTrue);
      expect(aiProvider.geminiInsight, contains('emergency fund'));

      // Now simulate service outage
      mockBackend.statusCode = 503;
      mockBackend.responseBody = {'detail': 'Service unavailable'};
      GeminiService.resetCooldown();

      await aiProvider.generateGeminiInsights(
        incomes: [
          IncomeModel(
            id: '1',
            userId: 'u1',
            amount: 40000,
            category: 'Salary',
            source: 'Bank',
            description: 'Salary',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        expenses: [
          ExpenseModel(
            id: '1',
            userId: 'u1',
            amount: 12000,
            category: 'Rent',
            paymentMethod: 'Bank Transfer',
            description: 'House rent',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ],
        budgets: [],
        goals: [],
      );

      expect(aiProvider.isInsightFromGemini, isFalse);
      expect(aiProvider.geminiInsight, isNotEmpty); // Local fallback populated
      expect(aiProvider.geminiErrorMessage, isNotEmpty);
    });
  });
}
