import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/financial_persona.dart';
import 'ai_cache_service.dart';

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
  static const String noInternet = 'No Internet Connection. Please check your network and try again.';
  static const String apiKeyInvalid = 'Gemini API Key Invalid. Please check your API key in the .env file.';
  static const String quotaExceeded = 'Gemini API Quota Exceeded. Please try again later or check your billing.';
  static const String serviceUnavailable = 'Gemini Service Unavailable. Please try again later.';
  static const String timeout = 'Gemini Timeout. The request took too long. Please check your internet connection.';
  static const String modelNotFound = 'Gemini model not found. The configured model may not exist.';
  static const String dnsFailure = 'DNS resolution failed. Please check your internet connection.';
  static const String sslFailure = 'SSL/TLS handshake failed. Please check your network or firewall settings.';
  static const String blockedNetwork = 'Connection blocked. This app may be blocked by your network or firewall.';
  static const String unknown = 'An unexpected error occurred. Please try again later.';
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

class GeminiService {
  static GenerativeModel? _model;
  static bool _initialized = false;
  static bool _hasApiKey = false;
  static String _lastModelName = '';
  static bool _connectionTested = false;
  static bool _connectionSuccessful = false;

  // Cooldown mechanism - only for genuine failures, not startup tests
  static GeminiErrorType _lastErrorType = GeminiErrorType.none;
  static DateTime? _cooldownUntil;
  static const Duration _quotaCooldown = Duration(minutes: 5);
  static const Duration _rateLimitCooldown = Duration(seconds: 30);
  static const Duration _serviceUnavailableCooldown = Duration(minutes: 2);
  static const Duration _networkErrorCooldown = Duration(seconds: 10);
  static const Duration _defaultCooldown = Duration(minutes: 1);

  /// ---- PUBLIC STATUS ----

  /// Whether Gemini is fully available (configured, initialized, and not on cooldown).
  static bool get isAvailable => _hasApiKey && _model != null && !isOnCooldown;

  /// Whether Gemini is configured and can ATTEMPT a request, regardless of cooldown.
  /// This is used for chat so Gemini always remains the primary engine.
  static bool get canAttemptRequest => _hasApiKey && _model != null;
  static bool get isConnectionTested => _connectionTested;
  static bool get isConnectionSuccessful => _connectionSuccessful;
  static String get currentModelName => _lastModelName;
  static bool get isOnCooldown => _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  static GeminiErrorType get lastErrorType => _lastErrorType;
  static DateTime? get cooldownUntil => _cooldownUntil;
  static Duration? get remainingCooldown {
    if (_cooldownUntil == null) return null;
    final remaining = _cooldownUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// ---- INITIALIZATION ----

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Only load .env if it hasn't been loaded already (main.dart loads it first).
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
      debugPrint('Gemini Init: .env loaded successfully');

      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      String modelName = dotenv.env['GEMINI_MODEL'] ?? 'gemini-3.5-flash-lite';

      // ====== VERIFY API KEY ======
      if (apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
        debugPrint('❌ Gemini Init: API Key Missing - No valid Gemini API key found');
        debugPrint('GeminiService: No valid API key found. Using local AI fallback.');
        _hasApiKey = false;
        return;
      }
      debugPrint('✓ Gemini Init: API Key Loaded');

      // ====== VERIFY MODEL NAME ======
      _lastModelName = modelName;
      final supportedModels = [
        'gemini-3.5-flash-lite',
        'gemini-3.5-flash',
        'gemini-3.6-flash',
        'gemini-3.7-flash',
        'gemini-3.1-flash-lite',
        'gemini-flash-latest',
      ];

      if (!supportedModels.contains(modelName)) {
        debugPrint('⚠️ Gemini Init: Configured model "$modelName" may not be supported. Attempting anyway.');
      }

      try {
        _model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.7,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 2048,
          ),
        );
        _hasApiKey = true;
        debugPrint('✓ Gemini Init: Model Initialized (model: $modelName)');
        debugPrint('[GEMINI] Model: $modelName');
      } catch (e) {
        debugPrint('❌ Gemini Init: Model Initialization failed: $e');
        _hasApiKey = false;
        return;
      }

      // ====== TEST CONNECTION (non-blocking, no cooldown on failure) ======
      // Do NOT apply cooldown for startup test failures. Only actual user
      // requests should trigger cooldown. This ensures Gemini remains the
      // primary engine even if the initial test fails.
      await _testConnection();

    } catch (e) {
      debugPrint('❌ GeminiService: Initialization failed: $e');
      debugPrint('   Exception type: ${e.runtimeType}');
      debugPrint('   Stack trace:');
      debugPrint('   ${StackTrace.current}');
      _hasApiKey = false;
    }
  }

  /// ---- CONNECTION TEST ----
  /// Tests the connection but does NOT apply cooldown on failure.
  /// Startup transient failures should not block Gemini from being used.
  static Future<void> _testConnection() async {
    if (!_hasApiKey || _model == null) return;

    try {
      debugPrint('GeminiService: Sending test request...');
      final testPrompt = 'Reply with the word OK.';
      final response = await _model!.generateContent(
        [Content.text(testPrompt)],
      );
      final text = response.text?.trim() ?? '';

      if (text.isNotEmpty && text.toUpperCase().contains('OK')) {
        _connectionSuccessful = true;
        _connectionTested = true;
        debugPrint('✓ Gemini Connection Successful');
      } else {
        _connectionSuccessful = true;
        _connectionTested = true;
        debugPrint('✓ Gemini Connection Successful (response: "$text")');
      }
    } catch (e) {
      _connectionTested = true;
      _connectionSuccessful = false;
      _lastErrorType = _classifyError(e);
      _logDetailedError('GeminiService: Connection test failed', e);
      // IMPORTANT: Do NOT apply cooldown for startup test failures.
      // The next actual user request will retry Gemini.
      debugPrint('GeminiService: Connection test failed but NOT applying cooldown. '
          'Next request will retry Gemini.');
    }
  }

  /// ---- ERROR CLASSIFICATION ----

  static GeminiErrorType _classifyError(Object e) {
    final msg = e.toString();

    if (msg.contains('429') || msg.contains('quota') || msg.contains('Quota') || msg.contains('RATE_LIMIT')) {
      if (msg.contains('RATE_LIMIT')) return GeminiErrorType.rateLimitExceeded;
      return GeminiErrorType.quotaExceeded;
    }
    if (msg.contains('401') || msg.contains('API_KEY_INVALID') || msg.contains('Unauthorized')) {
      return GeminiErrorType.invalidApiKey;
    }
    if (msg.contains('SocketException') || msg.contains('No address') || msg.contains('Connection refused')) {
      return GeminiErrorType.networkError;
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return GeminiErrorType.timeout;
    }
    if (msg.contains('500') || msg.contains('503') || msg.contains('Internal') || msg.contains('Unavailable')) {
      return GeminiErrorType.serviceUnavailable;
    }
    if (msg.contains('404') ||
        msg.contains('not found') ||
        msg.contains('NOT_FOUND') ||
        msg.contains('no longer available') ||
        msg.contains('does not exist')) {
      return GeminiErrorType.modelNotFound;
    }
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

  /// Resets cooldown so the next request will retry Gemini.
  static void resetCooldown() {
    _cooldownUntil = null;
    debugPrint('GeminiService: Cooldown reset. Next request will retry Gemini.');
  }

  /// ---- DETAILED ERROR LOGGING ----

  static void _logDetailedError(String prefix, Object e, [StackTrace? stack]) {
    debugPrint('❌ $prefix');
    debugPrint('   Exception type: ${e.runtimeType}');
    debugPrint('   Exception message: $e');
    debugPrint('   Error type: ${_classifyError(e).name}');

    final msg = e.toString();
    if (msg.contains('400') || msg.contains('Bad Request')) {
      debugPrint('   → Likely cause: Invalid model name or malformed request');
    } else if (msg.contains('401') || msg.contains('Unauthorized') || msg.contains('API_KEY_INVALID')) {
      debugPrint('   → Likely cause: Invalid API key');
    } else if (msg.contains('403') || msg.contains('Forbidden') || msg.contains('ACCESS_DENIED')) {
      debugPrint('   → Likely cause: API key not authorized or quota exceeded');
    } else if (msg.contains('404') || msg.contains('not found') || msg.contains('NOT_FOUND')) {
      debugPrint('   → Likely cause: Model not found. The model name may be incorrect.');
    } else if (msg.contains('429') || msg.contains('quota') || msg.contains('Quota') || msg.contains('RATE_LIMIT')) {
      debugPrint('   → Likely cause: API quota or rate limit exceeded');
    } else if (msg.contains('500') || msg.contains('503') || msg.contains('Internal') || msg.contains('Unavailable')) {
      debugPrint('   → Likely cause: Gemini server error (temporary)');
    } else if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('No address')) {
      debugPrint('   → Likely cause: No internet or network blocked');
    } else if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      debugPrint('   → Likely cause: Request timed out');
    } else if (msg.contains('TlsException') || msg.contains('HandshakeException') || msg.contains('certificate')) {
      debugPrint('   → Likely cause: SSL/TLS failure');
    } else if (msg.contains('DNS')) {
      debugPrint('   → Likely cause: DNS resolution failure');
    }

    if (stack != null) {
      debugPrint('   Stack trace (first 5 lines):');
      final lines = stack.toString().split('\n');
      for (int i = 0; i < (lines.length < 5 ? lines.length : 5); i++) {
        debugPrint('     ${lines[i]}');
      }
    }
  }

  /// ---- ERROR TO USER-FRIENDLY MESSAGE ----

  static String _errorToUserMessage(Object e) {
    final msg = e.toString();

    if (msg.contains('SocketException') || msg.contains('No address') || msg.contains('Connection refused')) {
      return GeminiErrorMessages.noInternet;
    }
    if (msg.contains('HandshakeException') || msg.contains('TlsException') || msg.contains('certificate')) {
      return GeminiErrorMessages.sslFailure;
    }
    if (msg.contains('DNS') || msg.contains('Name or service not known')) {
      return GeminiErrorMessages.dnsFailure;
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return GeminiErrorMessages.timeout;
    }
    if (msg.contains('401') || msg.contains('API_KEY_INVALID') || msg.contains('Unauthorized')) {
      return GeminiErrorMessages.apiKeyInvalid;
    }
    if (msg.contains('403') || msg.contains('quota') || msg.contains('Quota') || msg.contains('RATE_LIMIT')) {
      return GeminiErrorMessages.quotaExceeded;
    }
    if (msg.contains('404') ||
        msg.contains('not found') ||
        msg.contains('NOT_FOUND') ||
        msg.contains('no longer available') ||
        msg.contains('does not exist')) {
      return GeminiErrorMessages.modelNotFound;
    }
    if (msg.contains('500') || msg.contains('503') || msg.contains('Internal') || msg.contains('Unavailable')) {
      return GeminiErrorMessages.serviceUnavailable;
    }
    if (msg.contains('400') || msg.contains('Bad Request')) {
      return GeminiErrorMessages.serviceUnavailable;
    }

    return GeminiErrorMessages.unknown;
  }

  static const String _systemPrompt = '''You are SpendSense AI, an intelligent personal finance assistant.

You help users with:
• Budget Planning
• Expense Analysis
• Savings Suggestions
• Investment Basics
• Tax Basics
• Insurance Guidance
• Mutual Funds
• Financial Goals
• Loans and EMI
• Subscription Advice
• Credit Card Guidance
• General Financial Knowledge
• Monthly Financial Analysis
• Spending Optimization
• Wallet Management
• Subscription Analysis
• Monthly Financial Reports

Provide professional, accurate, easy-to-understand responses.
If calculations are required, perform them.
If users ask general financial questions, answer naturally.
Respond conversationally.
Never mention implementation details.
Never say you are in "local mode" or "offline mode" - always respond as the AI assistant.''';

  static String _buildFinancialContext({
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
    buf.writeln('=== FINANCIAL CONTEXT ===');
    if (financialPersona != null && financialPersona.isNotEmpty) {
      final persona = FinancialPersona.fromId(financialPersona);
      buf.writeln('User Financial Segment: ${persona?.label ?? financialPersona}');
      if (persona != null) {
        buf.writeln('Segment Guidance: ${persona.aiGuidance}');
      }
      buf.writeln('');
    }
    buf.writeln('Total Income: Rs. ${totalIncome.toStringAsFixed(2)}');
    buf.writeln('Total Expenses: Rs. ${totalExpense.toStringAsFixed(2)}');
    buf.writeln('Net Savings: Rs. ${savings.toStringAsFixed(2)}');
    buf.writeln('Savings Rate: ${savingsRate.toStringAsFixed(1)}%');
    buf.writeln('Health Score: ${healthScore ?? "N/A"}/100');
    buf.writeln('');

    buf.writeln('CATEGORY BREAKDOWN:');
    final categoryTotals = <String, double>{};
    for (final e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedCategories) {
      final pct = totalExpense > 0 ? ((e.value / totalExpense) * 100).toStringAsFixed(0) : '0';
      buf.writeln('${e.key}: Rs. ${e.value.toStringAsFixed(0)} ($pct%)');
    }
    buf.writeln('');

    buf.writeln('RECENT TRANSACTIONS:');
    for (final e in expenses.take(5)) {
      final d = e.date.toIso8601String().split('T')[0];
      final desc = e.description.isNotEmpty ? e.description : 'No description';
      buf.writeln('$d | ${e.category} | Rs. ${e.amount.toStringAsFixed(0)} | $desc');
    }
    buf.writeln('');

    buf.writeln('BUDGETS:');
    for (final b in budgets) {
      final status = b.isExceeded ? '(EXCEEDED)' : '(On track)';
      buf.writeln('${b.category}: Rs. ${b.spentAmount.toStringAsFixed(0)} / Rs. ${b.budgetAmount.toStringAsFixed(0)} $status');
    }
    buf.writeln('');

    buf.writeln('GOALS:');
    for (final g in goals) {
      buf.writeln('${g.title}: Rs. ${g.savedAmount.toStringAsFixed(0)} / Rs. ${g.targetAmount.toStringAsFixed(0)} (${(g.progress * 100).toStringAsFixed(0)}%)');
    }

    return buf.toString();
  }

  static Future<GeminiResponse> generateSavingsSuggestions({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    String? financialPersona,
  }) async {
    if (!canAttemptRequest) {
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: GeminiService.isOnCooldown
            ? 'Using Local AI while Gemini is temporarily unavailable.'
            : 'Gemini is not configured.',
        errorType: GeminiService.lastErrorType,
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
      return GeminiResponse(content: cached, isFromCache: true);
    }

    try {
      debugPrint('Gemini Request Started: savings_suggestions');
      debugPrint('[GEMINI] Request Started: savings_suggestions');
      final context = _buildFinancialContext(
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

      debugPrint('Gemini Request Sent: savings_suggestions');
      final stopwatch = Stopwatch()..start();
      final response = await _model!.generateContent([Content.text(prompt)]);
      stopwatch.stop();
      debugPrint('Gemini Response Received: savings_suggestions (${stopwatch.elapsedMilliseconds}ms)');
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        debugPrint('Gemini Error: Empty response for savings_suggestions');
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
      return GeminiResponse(content: text);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Savings suggestions failed', e);
      debugPrint('Fallback Activated: savings_suggestions -> Local AI');
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

  static Future<GeminiResponse> generateMonthlySummary({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? healthScore,
    String? financialPersona,
  }) async {
    if (!canAttemptRequest) {
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: GeminiService.isOnCooldown
            ? 'Using Local AI while Gemini is temporarily unavailable.'
            : 'Gemini is not configured.',
        errorType: GeminiService.lastErrorType,
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
      return GeminiResponse(content: cached, isFromCache: true);
    }

    try {
      debugPrint('Gemini Request Started: monthly_summary');
      debugPrint('[GEMINI] Request Started: monthly_summary');
            final context = _buildFinancialContext(
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

      debugPrint('Gemini Request Sent: monthly_summary');
      final stopwatch = Stopwatch()..start();
      final response = await _model!.generateContent([Content.text(prompt)]);
      stopwatch.stop();
      debugPrint('Gemini Response Received: monthly_summary (${stopwatch.elapsedMilliseconds}ms)');
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        debugPrint('Gemini Error: Empty response for monthly_summary');
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
      return GeminiResponse(content: text);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Monthly summary failed', e);
      debugPrint('Fallback Activated: monthly_summary -> Local AI');
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

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
      debugPrint('Gemini Request Started: goal_recommendations');
      debugPrint('[GEMINI] Request Started: goal_recommendations');
      final context = _buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        financialPersona: financialPersona,
      );

      final prompt = 'You are a financial goal planning advisor. Analyze these savings goals.\n\n'
          '$context\n\n'
          'For each goal, provide ONE sentence of specific advice. Then give ONE overall recommendation.\n\n'
          'Keep response concise (3-4 sentences). Be encouraging and actionable.';

      debugPrint('Gemini Request Sent: goal_recommendations');
      final stopwatch = Stopwatch()..start();
      final response = await _model!.generateContent([Content.text(prompt)]);
      stopwatch.stop();
      debugPrint('Gemini Response Received: goal_recommendations (${stopwatch.elapsedMilliseconds}ms)');
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        debugPrint('Gemini Error: Empty response for goal_recommendations');
        return const GeminiResponse(content: '', isFromFallback: true);
      }
      return GeminiResponse(content: text);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Goal recommendations failed', e);
      debugPrint('Fallback Activated: goal_recommendations -> Local AI');
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }

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
    // If the model is NOT configured at all, use Local AI.
    if (!canAttemptRequest) {
      debugPrint('Gemini Error: Not configured (missing API key or model). Fallback Activated.');
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: 'Gemini is not configured. Using Local AI.',
        errorType: GeminiService.lastErrorType,
      );
    }

    // Forces a retry of Gemini even if a previous cooldown is still active.
    // A new user message is a new intent, so always attempt Gemini first.
    resetCooldown();

    final sanitized = message.trim();
    final safeMessage = sanitized.length > 500 ? sanitized.substring(0, 500) : sanitized;

    try {
      debugPrint('Gemini Request Started: chat');
      debugPrint('[GEMINI] Request Started');
      final context = _buildFinancialContext(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        healthScore: healthScore,
        financialPersona: financialPersona,
      );

      // Build prompt with system instructions, financial context, and conversation history.
      final buffer = StringBuffer();
      buffer.writeln(_systemPrompt);
      buffer.writeln('');
      buffer.writeln('You have access to the user\'s complete financial data:');
      buffer.writeln('');
      buffer.writeln(context);
      buffer.writeln('');
      buffer.writeln('Guidelines:');
      buffer.writeln('1. Be helpful and thorough. Answer ANY financial question the user asks.');
      buffer.writeln('2. Give specific actionable advice based on their actual data');
      buffer.writeln('3. Use Rs. for currency');
      buffer.writeln('4. Be encouraging and non-judgmental');
      buffer.writeln('5. If asked about general financial topics (investments, taxes, insurance, loans, etc.), provide helpful educational information');
      buffer.writeln('6. Reference their actual numbers when giving advice');
      buffer.writeln('7. Never make up data - only use what is provided');
      buffer.writeln('8. For general financial questions, provide practical, accurate advice');
      buffer.writeln('9. Keep responses concise but informative (3-6 sentences)');
      buffer.writeln('');
      buffer.writeln('=== CONVERSATION HISTORY ===');
      buffer.writeln('(Earlier messages are listed oldest to newest.)');

      final systemContext = buffer.toString();

      // Build the conversation content parts.
      // History from Firestore is newest-first; reverse for oldest-first.
      final orderedHistory = (history ?? const <ChatMessageModel>[]).reversed.toList();
      final contents = <Content>[
        Content.text(systemContext),
        for (final h in orderedHistory.take(10)) ...[
          Content.text(h.question),
          Content.model([TextPart(h.response)]),
        ],
        Content.text(safeMessage),
      ];

      debugPrint('Gemini Request Sent: chat (message: "$safeMessage", history: ${history?.length ?? 0} msgs)');
      debugPrint('[GEMINI] Request Sent');
      final stopwatch = Stopwatch()..start();
      final response = await _model!.generateContent(contents);
      stopwatch.stop();
      debugPrint('Gemini Response Received: chat (${stopwatch.elapsedMilliseconds}ms)');
      debugPrint('[GEMINI] Response Received');
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        debugPrint('Gemini Error: Empty response for chat');
        return const GeminiResponse(
          content: '',
          isFromFallback: true,
        );
      }
      debugPrint('Gemini Response Time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[GEMINI] Response Parsed Successfully');
      return GeminiResponse(content: text);
    } catch (e) {
      _lastErrorType = _classifyError(e);
      _applyCooldown(_lastErrorType);
      _logDetailedError('GeminiService: Chat failed (Gemini Error - exact exception)', e);
      debugPrint('[GEMINI] Request Failed');
      debugPrint('[GEMINI] Error Type: ${_lastErrorType.name}');
      debugPrint('[GEMINI] Error Message: ${_errorToUserMessage(e)}');
      debugPrint('Fallback Activated: chat -> Local AI');
      return GeminiResponse(
        content: '',
        isFromFallback: true,
        errorMessage: _errorToUserMessage(e),
        errorType: _lastErrorType,
      );
    }
  }
}