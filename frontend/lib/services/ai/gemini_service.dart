import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';
import '../../models/chat_message_model.dart';
import '../api_config.dart';
import 'ai_cache_service.dart';
import 'gemini_backend_client.dart';

/// Error types that Gemini can return.
enum GeminiErrorType {
  none,
  quotaExceeded,
  rateLimitExceeded,
  invalidApiKey,
  networkError,
  timeout,
  serviceUnavailable,
  modelNotFound,
  unknown,
}

/// User-friendly error messages for specific failure modes.
class GeminiErrorMessages {
  static const String noInternet =
      'No Internet Connection. Please check your network and try again.';
  static const String authFailed =
      'Backend authentication failed. Please verify your authentication key in Server Settings.';
  static const String apiKeyInvalid =
      'Gemini API Key is not configured on the server. Please contact the app developer.';
  static const String quotaExceeded =
      'Gemini API Quota Exceeded. Please try again later or check your billing.';
  static const String serviceUnavailable =
      'Gemini Service Unavailable. Please try again later.';
  static const String timeout =
      'Gemini Timeout. The request took too long. Please check your internet connection.';
  static const String modelNotFound =
      'Gemini model not found. The configured model may not exist.';
  static const String dnsFailure =
      'DNS resolution failed. Please check your internet connection.';
  static const String sslFailure =
      'SSL/TLS handshake failed. Please check your network or firewall settings.';
  static const String blockedNetwork =
      'Connection blocked. This app may be blocked by your network or firewall.';
  static const String unknown =
      'An unexpected error occurred. Please try again later.';
}

class GeminiResponse {
  final String content;
  final bool isFromCache;
  final bool isFromFallback;
  final String? errorMessage;
  final GeminiErrorType errorType;

  const GeminiResponse({
    required this.content,
    this.isFromCache = false,
    this.isFromFallback = false,
    this.errorMessage,
    this.errorType = GeminiErrorType.none,
  });
}

/// Gemini AI service for the Flutter app.
///
/// Communicates EXCLUSIVELY through the secure SpendSense AI backend proxy.
/// The Gemini API key remains strictly on the server and is never bundled in Flutter.
class GeminiService {
  static String get backendBaseUrl => ApiConfig.baseUrl;

  static bool _initialized = false;
  static bool _backendReady = false;
  static bool _backendReachable = false;
  static bool _geminiConfigured = false;
  static String _lastModelName = '';
  static bool _connectionTested = false;
  static bool _connectionSuccessful = false;

  static const Duration _requestTimeout = Duration(seconds: 25);

  // Cooldown mechanism - only for genuine failures, not startup tests.
  static GeminiErrorType _lastErrorType = GeminiErrorType.none;
  static DateTime? _cooldownUntil;
  static const Duration _quotaCooldown = Duration(seconds: 8);
  static const Duration _rateLimitCooldown = Duration(seconds: 5);
  static const Duration _serviceUnavailableCooldown = Duration(seconds: 4);
  static const Duration _networkErrorCooldown = Duration(seconds: 3);
  static const Duration _defaultCooldown = Duration(seconds: 2);

  /// ---- PUBLIC STATUS ----

  /// Whether Gemini is available (backend reachable, configured, and not on cooldown).
  static bool get isAvailable => _backendReady && !isOnCooldown;

  /// Whether a Gemini request can be attempted (backend configured).
  static bool get canAttemptRequest => _backendReady;

  /// Whether the backend host answered /health.
  static bool get isBackendReachable => _backendReachable;

  /// Whether backend has a valid Gemini key configured.
  static bool get isGeminiConfigured => _geminiConfigured;

  static bool get isConnectionTested => _connectionTested;
  static bool get isConnectionSuccessful => _connectionSuccessful;
  static String get currentModelName => _lastModelName;
  static bool get isOnCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  static GeminiErrorType get lastErrorType => _lastErrorType;
  static DateTime? get cooldownUntil => _cooldownUntil;
  static Duration? get remainingCooldown {
    if (_cooldownUntil == null) return null;
    final remaining = _cooldownUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// ---- INITIALIZATION ----

  static Future<void> initialize({bool force = false}) async {
    if (_initialized && _backendReady && !force) return;
    _initialized = true;

    try {
      await ApiConfig.loadSavedUrl();
      if (!dotenv.isInitialized) {
        try {
          await dotenv.load(fileName: '.env');
        } catch (_) {}
      }

      final discovered = await discoverReachableBackend(
        candidates: ApiConfig.candidateBaseUrls,
        timeout: const Duration(seconds: 15),
      );

      if (discovered == null) {
        debugPrint('❌ Gemini Init: no reachable backend candidate found within probe timeout.');
        _backendReachable = false;
        _backendReady = false;
        return;
      }

      ApiConfig.setActiveBaseUrl(discovered.url);
      _backendReachable = true;
      _geminiConfigured = discovered.health.geminiConfigured;
      _lastModelName = discovered.health.model;

      if (!_geminiConfigured) {
        debugPrint('❌ Gemini Init: Backend is running at ${discovered.url}, but GEMINI_API_KEY is not configured on server.');
        _backendReady = false;
        return;
      }

      _backendReady = true;
      debugPrint('✓ Gemini Init: Backend ready at ${discovered.url} (model: $_lastModelName)');

      // Initial test connection without triggering user cooldown
      await _testConnection();
    } catch (e) {
      debugPrint('❌ GeminiService initialization error: $e');
      _backendReachable = false;
      _backendReady = false;
    }
  }

  /// Re-probes backend health candidates concurrently. Safe to call repeatedly and makes the app self-healing.
  static Future<bool> refreshBackendStatus() async {
    try {
      await ApiConfig.loadSavedUrl();
      if (!dotenv.isInitialized) {
        try {
          await dotenv.load(fileName: '.env');
        } catch (_) {}
      }

      final discovered = await discoverReachableBackend(
        candidates: ApiConfig.candidateBaseUrls,
        timeout: const Duration(seconds: 15),
      );

      if (discovered == null) {
        debugPrint('❌ Gemini status refresh: no reachable backend candidate found.');
        _backendReachable = false;
        _backendReady = false;
        return false;
      }

      ApiConfig.setActiveBaseUrl(discovered.url);
      _backendReachable = true;
      _geminiConfigured = discovered.health.geminiConfigured;
      _lastModelName = discovered.health.model;

      if (_geminiConfigured) {
        _backendReady = true;
        _connectionTested = true;
        _connectionSuccessful = true;
        debugPrint('✓ Gemini status refreshed: live at ${discovered.url} (model: $_lastModelName)');
        return true;
      } else {
        debugPrint('❌ Gemini status refreshed: backend up at ${discovered.url}, but GEMINI_API_KEY not configured.');
        _backendReady = false;
        return false;
      }
    } catch (e) {
      debugPrint('❌ Gemini status refresh failed: $e');
      _backendReachable = false;
      _backendReady = false;
      return false;
    }
  }

  /// ---- CONNECTION TEST ----
  static Future<void> _testConnection() async {
    if (!_backendReady) return;

    try {
      debugPrint('GeminiService: Sending lightweight health test request...');
      final text = await sendGeminiChatRequest(
        baseUrl: backendBaseUrl,
        prompt: 'Reply with OK.',
        timeout: const Duration(seconds: 15),
      );

      if (text.isNotEmpty) {
        _connectionSuccessful = true;
        _connectionTested = true;
        debugPrint('✓ Gemini Connection Verified (model response: "$text")');
      }
    } catch (e) {
      _connectionTested = true;
      _connectionSuccessful = false;
      _lastErrorType = _classifyError(e);
      _logDetailedError('GeminiService: Connection test failed', e);
      debugPrint('GeminiService: Startup test failed, but next user request will retry Gemini.');
    }
  }

  /// ---- ERROR CLASSIFICATION ----

  static GeminiErrorType _classifyError(Object e) {
    if (e is GeminiBackendException) {
      if (e.statusCode == 0) {
        return e.userMessage.toLowerCase().contains('timed out')
            ? GeminiErrorType.timeout
            : GeminiErrorType.networkError;
      }
      return _classifyStatus(e.statusCode);
    }

    final msg = e.toString();
    if (msg.contains('429') || msg.contains('quota') || msg.contains('RATE_LIMIT')) {
      return GeminiErrorType.rateLimitExceeded;
    }
    if (msg.contains('401') || msg.contains('403') || msg.contains('API_KEY_INVALID')) {
      return GeminiErrorType.invalidApiKey;
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('No address')) {
      return GeminiErrorType.networkError;
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return GeminiErrorType.timeout;
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return GeminiErrorType.serviceUnavailable;
    }
    if (msg.contains('404')) {
      return GeminiErrorType.modelNotFound;
    }
    return GeminiErrorType.unknown;
  }

  static GeminiErrorType _classifyStatus(int statusCode) {
    if (statusCode == 429) return GeminiErrorType.rateLimitExceeded;
    if (statusCode == 401 || statusCode == 403) return GeminiErrorType.invalidApiKey;
    if (statusCode == 404) return GeminiErrorType.modelNotFound;
    if (statusCode >= 500) return GeminiErrorType.serviceUnavailable;
    return GeminiErrorType.unknown;
  }

  /// ---- COOLDOWN ----

  static void _applyCooldown(GeminiErrorType errorType) {
    switch (errorType) {
      case GeminiErrorType.quotaExceeded:
        _cooldownUntil = DateTime.now().add(_quotaCooldown);
        break;
      case GeminiErrorType.rateLimitExceeded:
        _cooldownUntil = DateTime.now().add(_rateLimitCooldown);
        break;
      case GeminiErrorType.serviceUnavailable:
        _cooldownUntil = DateTime.now().add(_serviceUnavailableCooldown);
        break;
      case GeminiErrorType.networkError:
        _cooldownUntil = DateTime.now().add(_networkErrorCooldown);
        break;
      default:
        _cooldownUntil = DateTime.now().add(_defaultCooldown);
    }
    debugPrint('⏳ Gemini on cooldown until ${_cooldownUntil!.toLocal()} (${errorType.name})');
  }

  static void resetCooldown() {
    _cooldownUntil = null;
    debugPrint('GeminiService: Cooldown reset.');
  }

  static void _logDetailedError(String prefix, Object e) {
    debugPrint('❌ $prefix');
    debugPrint('   Exception: $e');
    debugPrint('   Error type: ${_classifyError(e).name}');
  }

  static String _errorToUserMessage(Object e) {
    if (e is GeminiBackendException && e.userMessage.isNotEmpty) {
      return e.userMessage;
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return GeminiErrorMessages.noInternet;
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return GeminiErrorMessages.timeout;
    }
    if (msg.contains('401')) {
      return GeminiErrorMessages.authFailed;
    }
    if (msg.contains('403') || msg.contains('API_KEY_INVALID')) {
      return GeminiErrorMessages.apiKeyInvalid;
    }
    if (msg.contains('429') || msg.contains('quota')) {
      return GeminiErrorMessages.quotaExceeded;
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return GeminiErrorMessages.serviceUnavailable;
    }
    return GeminiErrorMessages.unknown;
  }

  /// Context builder for personalized finance tips.
  static String buildFinancialContext({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    String? financialPersona,
  }) {
    final totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amount);
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final savings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? ((savings / totalIncome) * 100) : 0;

    final buf = StringBuffer();
    buf.writeln('Income: Rs.${totalIncome.toStringAsFixed(0)} | '
        'Expenses: Rs.${totalExpense.toStringAsFixed(0)} | '
        'Savings: Rs.${savings.toStringAsFixed(0)} (${savingsRate.toStringAsFixed(0)}%)');
    if (healthScore != null) buf.writeln('Health: $healthScore/100');

    final categoryTotals = <String, double>{};
    for (final e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isNotEmpty) {
      buf.writeln('Top: ${sorted.take(3).map((e) => '${e.key} Rs.${e.value.toStringAsFixed(0)}').join(', ')}');
    }
    if (budgets.isNotEmpty) {
      final over = budgets.where((b) => b.isExceeded).length;
      buf.writeln('Budgets: ${budgets.length} ($over over)');
    }
    if (goals.isNotEmpty) {
      buf.writeln('Goals: ${goals.length}');
    }

    final out = buf.toString();
    return out.length > 500 ? out.substring(0, 500) : out;
  }

  /// ---- SHARED BACKEND PROXY REQUEST PATH ----
  static Future<String> _requestGeminiText({
    required String prompt,
    List<Map<String, String>>? history,
    required String feature,
  }) async {
    return sendGeminiChatRequest(
      baseUrl: backendBaseUrl,
      prompt: prompt,
      history: history ?? const <Map<String, String>>[],
      timeout: _requestTimeout,
    );
  }

  /// Generates savings suggestions through backend Gemini proxy.
  static Future<GeminiResponse> generateSavingsSuggestions({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    String? financialPersona,
  }) async {
    if (!canAttemptRequest) {
      await refreshBackendStatus();
    }
    if (!canAttemptRequest) {
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: isOnCooldown
            ? 'Using Local AI while Gemini is temporarily unavailable.'
            : 'Gemini AI is currently unavailable. Using local suggestions.',
        errorType: lastErrorType,
      );
    }

    final cached = await AICacheService.getCachedResponse(
      cacheKey: 'savings_suggestions',
      incomes: incomes,
      expenses: expenses,
      budgets: budgets,
      goals: goals,
    );
    if (cached != null) {
      return GeminiResponse(content: cached, isFromCache: true, isFromFallback: false);
    }

    try {
      debugPrint('[GEMINI] Request Started: savings_suggestions');
      final context = buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        healthScore: healthScore,
        financialPersona: financialPersona,
      );

      final prompt = 'You are a professional financial advisor for SpendSense AI. '
          'Analyze the user financial data and provide personalized advice.\n\n'
          '$context\n\n'
          'Based on this data, provide:\n'
          '1. A brief overall assessment (1 sentence)\n'
          '2. The most important area to focus on (1 sentence)\n'
          '3. One specific actionable recommendation they can implement today (1 sentence)\n'
          '4. An encouraging closing statement (1 sentence)\n\n'
          'Rules: Be concise (max 4 sentences). Use Rs. for currency. '
          'Be specific with numbers. Professional but friendly tone. Actionable, not generic.';

      final stopwatch = Stopwatch()..start();
      final text = await _requestGeminiText(
        prompt: prompt,
        feature: 'savings_suggestions',
      );
      stopwatch.stop();
      debugPrint('[GEMINI] Response Received: savings_suggestions (${stopwatch.elapsedMilliseconds}ms)');

      if (text.isEmpty) {
        return const GeminiResponse(content: '', isFromFallback: true);
      }

      await AICacheService.cacheResponse(
        cacheKey: 'savings_suggestions',
        response: text,
        incomes: incomes,
        expenses: expenses,
        budgets: budgets,
        goals: goals,
      );
      return GeminiResponse(content: text, isFromFallback: false);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Savings suggestions failed', e);
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

  /// Generates concise monthly summary through backend Gemini proxy.
  static Future<GeminiResponse> generateMonthlySummary({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    String? financialPersona,
  }) async {
    if (!canAttemptRequest) {
      await refreshBackendStatus();
    }
    if (!canAttemptRequest) {
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: isOnCooldown
            ? 'Using Local AI while Gemini is temporarily unavailable.'
            : 'Gemini AI is currently unavailable.',
        errorType: lastErrorType,
      );
    }

    final cached = await AICacheService.getCachedResponse(
      cacheKey: 'monthly_summary',
      incomes: incomes,
      expenses: expenses,
      budgets: budgets,
      goals: goals,
    );
    if (cached != null) {
      return GeminiResponse(content: cached, isFromCache: true, isFromFallback: false);
    }

    try {
      debugPrint('[GEMINI] Request Started: monthly_summary');
      final context = buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        healthScore: healthScore,
        financialPersona: financialPersona,
      );

      final prompt = 'You are a professional financial analyst. Create a concise monthly financial summary.\n\n'
          '$context\n\n'
          'Provide a brief summary (3-4 sentences) covering:\n'
          '1. Overall financial health status this month\n'
          '2. Top spending category and its percentage of total expenses\n'
          '3. One specific actionable recommendation\n'
          '4. Encouraging closing statement\n\n'
          'Keep it conversational, professional, and encouraging. Do not use markdown.';

      final stopwatch = Stopwatch()..start();
      final text = await _requestGeminiText(
        prompt: prompt,
        feature: 'monthly_summary',
      );
      stopwatch.stop();
      debugPrint('[GEMINI] Response Received: monthly_summary (${stopwatch.elapsedMilliseconds}ms)');

      if (text.isEmpty) {
        return const GeminiResponse(content: '', isFromFallback: true);
      }

      await AICacheService.cacheResponse(
        cacheKey: 'monthly_summary',
        response: text,
        incomes: incomes,
        expenses: expenses,
        budgets: budgets,
        goals: goals,
      );
      return GeminiResponse(content: text, isFromFallback: false);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Monthly summary failed', e);
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

  /// Generates goal recommendations through backend Gemini proxy.
  static Future<GeminiResponse> generateGoalRecommendations({
    required List<GoalModel> goals,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    String? financialPersona,
  }) async {
    if (!canAttemptRequest || goals.isEmpty) {
      return const GeminiResponse(content: '', isFromFallback: true);
    }

    try {
      debugPrint('[GEMINI] Request Started: goal_recommendations');
      final context = buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        financialPersona: financialPersona,
      );

      final prompt = 'You are a financial goal planning advisor. Analyze these savings goals.\n\n'
          '$context\n\n'
          'For each goal, provide ONE sentence of specific advice. Then give ONE overall recommendation.\n\n'
          'Keep response concise (3-4 sentences). Be encouraging and actionable.';

      final stopwatch = Stopwatch()..start();
      final text = await _requestGeminiText(
        prompt: prompt,
        feature: 'goal_recommendations',
      );
      stopwatch.stop();
      debugPrint('[GEMINI] Response Received: goal_recommendations (${stopwatch.elapsedMilliseconds}ms)');

      if (text.isEmpty) {
        return const GeminiResponse(content: '', isFromFallback: true);
      }
      return GeminiResponse(content: text, isFromFallback: false);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Goal recommendations failed', e);
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

  /// Interactive AI Chat routed through backend Gemini proxy.
  static Future<GeminiResponse> chat({
    required String message,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    List<ChatMessageModel>? history,
    String? financialPersona,
  }) async {
    // If backend status was not yet confirmed ready, re-probe now
    if (!_backendReady) {
      await refreshBackendStatus();
    }

    // Force retry for a newly typed user message
    resetCooldown();

    final sanitized = message.trim();
    final safeMessage = sanitized.length > 500 ? sanitized.substring(0, 500) : sanitized;

    try {
      final context = buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        healthScore: healthScore,
        financialPersona: financialPersona,
      );

      final prompt =
          'You are SpendSense AI, an intelligent personal finance assistant. Provide helpful, conversational advice (2-5 sentences), and use Rs. for Indian currency amounts.\n$context\nUser: $safeMessage';

      final orderedHistory = (history ?? const <ChatMessageModel>[]).reversed.toList();
      final historyPayload = <Map<String, String>>[
        for (final h in orderedHistory.take(2)) ...[
          {'role': 'user', 'text': h.question.length > 250 ? h.question.substring(0, 250) : h.question},
          {'role': 'model', 'text': h.response.length > 250 ? h.response.substring(0, 250) : h.response},
        ],
      ];

      debugPrint('[GEMINI] Request Sent: chat (message: "$safeMessage") target: $backendBaseUrl');
      final stopwatch = Stopwatch()..start();
      final text = await sendGeminiChatRequest(
        baseUrl: backendBaseUrl,
        prompt: prompt,
        history: historyPayload,
        timeout: _requestTimeout,
      );
      stopwatch.stop();
      debugPrint('[GEMINI] Response Received: chat (${stopwatch.elapsedMilliseconds}ms)');

      if (text.isEmpty) {
        return const GeminiResponse(content: '', isFromFallback: true);
      }

      // Successful live response confirms backend and Gemini are ready
      _backendReady = true;
      _backendReachable = true;
      _geminiConfigured = true;
      _connectionSuccessful = true;
      ApiConfig.setActiveBaseUrl(backendBaseUrl);

      return GeminiResponse(content: text, isFromFallback: false);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Chat request failed', e);
      if (_lastErrorType == GeminiErrorType.networkError ||
          _lastErrorType == GeminiErrorType.timeout) {
        if (ApiConfig.customBaseUrl == null) {
          ApiConfig.resetActiveBaseUrl();
        }
        _backendReady = false;
        _backendReachable = false;
      }
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }
}