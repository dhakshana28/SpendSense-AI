import 'package:flutter/material.dart';

import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../models/wallet_model.dart';
import '../services/ai/expense_categorizer.dart';
import '../services/ai/spending_predictor.dart';
import '../services/ai/savings_suggester.dart';
import '../services/ai/health_score.dart';
import '../services/ai/subscription_detector.dart';
import '../services/ai/goal_planner.dart';
import '../services/ai/gemini_service.dart';
import '../services/ai/ai_insights_service.dart';
import '../services/ai/ai_cache_service.dart';
import '../models/chat_message_model.dart';
import '../services/ai/chat_history_service.dart';
import '../services/notification_service.dart';

class AIProvider extends ChangeNotifier {
  // ===== LOCAL AI (Always Available) =====

  // Categories
  String _predictedCategory = 'Others';
  String get predictedCategory => _predictedCategory;

  // Prediction
  SpendingPrediction? _prediction;
  SpendingPrediction? get prediction => _prediction;

  // Savings
  List<SavingsSuggestion> _suggestions = [];
  List<SavingsSuggestion> get suggestions => _suggestions;

  // Health score
  HealthScoreResult? _healthScore;
  HealthScoreResult? get healthScore => _healthScore;

  // Subscriptions
  List<DetectedSubscription> _subscriptions = [];
  List<DetectedSubscription> get subscriptions => _subscriptions;
  double get totalMonthlySubscriptions =>
      _subscriptions.fold(0.0, (sum, s) => sum + s.monthlyCost);

  // Goal plans
  List<GoalPlan> _goalPlans = [];
  List<GoalPlan> get goalPlans => _goalPlans;

  // ===== GEMINI AI =====
  String _geminiInsight = '';
  String get geminiInsight => _geminiInsight;
  String _monthlySummary = '';
  String get monthlySummary => _monthlySummary;
  String _goalRecommendations = '';
  String get goalRecommendations => _goalRecommendations;
  int _geminiLoadingCount = 0;
  bool get isGeminiLoading => _geminiLoadingCount > 0;
  bool _geminiAvailable = false;
  bool get geminiAvailable => _geminiAvailable;
  String _geminiErrorMessage = '';
  String get geminiErrorMessage => _geminiErrorMessage;

  // Insights loading state
  bool _isInsightsLoading = false;
  bool get isInsightsLoading => _isInsightsLoading;
  DateTime? _lastInsightsUpdated;
  DateTime? get lastInsightsUpdated => _lastInsightsUpdated;

  bool _lastChatWasFallback = false;
  bool get lastChatWasFallback => _lastChatWasFallback;

  /// True when the app is using Local AI because Gemini is unavailable or on cooldown.
  bool get isUsingLocalFallback =>
      _lastChatWasFallback ||
      _geminiErrorMessage == 'Using Local AI while Gemini is temporarily unavailable.' ||
      GeminiService.isOnCooldown;

  // ===== AI INSIGHTS =====
  List<AIInsight> _insights = [];
  List<AIInsight> get insights => _insights;

  // ===== CHAT HISTORY =====
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  List<ChatMessageModel> _chatHistory = [];
  List<ChatMessageModel> get chatHistory => _chatHistory;
  bool _isChatLoading = false;
  bool get isChatLoading => _isChatLoading;

  // ===== SHARED =====
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  String? _error;
  String? get error => _error;

  Future<void> initializeGemini() async {
    await GeminiService.initialize();
    // _geminiAvailable should reflect whether Gemini is CONFIGURED (has API key + model),
    // NOT whether it's currently off-cooldown. A startup transient failure should not
    // permanently mark Gemini as unavailable; chat must always attempt Gemini first.
    _geminiAvailable = GeminiService.canAttemptRequest;
    if (!_geminiAvailable) {
      _geminiErrorMessage = 'Gemini AI is currently unavailable. Using Local AI.';
    } else {
      _geminiErrorMessage = '';
    }
    debugPrint('Gemini Initialized: model=${GeminiService.currentModelName}, '
        'available=$_geminiAvailable, configured=${GeminiService.canAttemptRequest}');
    notifyListeners();
  }

  /// Whether the provider should reflect that Gemini is configured (regardless of cooldown).
  bool get isGeminiConfigured => GeminiService.canAttemptRequest;

  // ===== LOCAL AI METHODS =====

  void categorizeExpense(String description, {String? title}) {
    _predictedCategory = ExpenseCategorizer.categorize(description, title: title);
    notifyListeners();
  }

  List<String> getSuggestedCategories() {
    return ExpenseCategorizer.suggestCategories();
  }

  void predictSpending(List<ExpenseModel> expenses) {
    _prediction = SpendingPredictor.predict(expenses);
    notifyListeners();
  }

  void generateSuggestions({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
  }) {
    _suggestions = SavingsSuggester.generate(
      incomes: incomes, expenses: expenses, budgets: budgets,
    );
    notifyListeners();
  }

  void calculateHealthScore({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<GoalModel> goals,
    required List<BudgetModel> budgets,
  }) {
    _healthScore = FinancialHealthScoreCalculator.calculate(
      incomes: incomes, expenses: expenses, goals: goals, budgets: budgets,
    );
    notifyListeners();
  }

  void detectSubscriptions(List<ExpenseModel> expenses) {
    _subscriptions = SubscriptionDetector.detect(expenses);
    notifyListeners();
  }

  void analyzeGoals({
    required List<GoalModel> goals,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
  }) {
    _goalPlans = [];
    for (final goal in goals) {
      final plan = GoalPlanner.analyze(goal: goal, incomes: incomes, expenses: expenses);
      if (plan != null) _goalPlans.add(plan);
    }
    notifyListeners();
  }

  // ===== AI INSIGHTS =====
  Future<void> generateInsights({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) async {
    _isInsightsLoading = true;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    // Run insights generation off the UI thread
    _insights = await Future(() => AIInsightsService.generateAll(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
    ));
    stopwatch.stop();
    _isInsightsLoading = false;
    debugPrint('AI Insights generation completed in ${stopwatch.elapsedMilliseconds}ms '
        '(${_insights.length} insights)');
    _lastInsightsUpdated = DateTime.now();
    notifyListeners();
  }

  // ===== GEMINI METHODS WITH LOCAL AI FALLBACK =====

    Future<void> generateGeminiInsights({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    if (!_geminiAvailable) {
      _geminiInsight = _buildLocalInsight(incomes, expenses, budgets, goals);
      if (GeminiService.isOnCooldown) {
        _geminiErrorMessage = 'Using Local AI while Gemini is temporarily unavailable.';
      } else {
        _geminiErrorMessage = 'Gemini AI is currently unavailable. Using local AI suggestions.';
      }
      notifyListeners();
      return;
    }

    _geminiLoadingCount++;
    _geminiErrorMessage = '';
    notifyListeners();

    final response = await GeminiService.generateSavingsSuggestions(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      healthScore: _healthScore?.score,
      financialPersona: financialPersona,
    );

    _geminiLoadingCount--;
    if (_geminiLoadingCount < 0) _geminiLoadingCount = 0;

    if (response.isFromFallback || response.content.isEmpty) {
      _geminiInsight = _buildLocalInsight(incomes, expenses, budgets, goals);
      _geminiErrorMessage = response.errorMessage ??
          (GeminiService.isOnCooldown
              ? 'Using Local AI while Gemini is temporarily unavailable.'
              : 'Gemini AI is currently unavailable. Using local AI suggestions.');
      notifyListeners();
      return;
    }

    _geminiInsight = response.content;
    _geminiErrorMessage = '';
    notifyListeners();
  }

    Future<void> generateMonthlySummary({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    if (!_geminiAvailable) {
      _monthlySummary = _buildLocalSummary(incomes, expenses);
      notifyListeners();
      return;
    }

    _geminiLoadingCount++;
    notifyListeners();

    final response = await GeminiService.generateMonthlySummary(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      healthScore: _healthScore?.score,
      financialPersona: financialPersona,
    );

    _geminiLoadingCount--;
    if (_geminiLoadingCount < 0) _geminiLoadingCount = 0;

    if (response.isFromFallback || response.content.isEmpty) {
      _monthlySummary = _buildLocalSummary(incomes, expenses);
      notifyListeners();
      return;
    }

    _monthlySummary = response.content;
    notifyListeners();
  }

    Future<void> generateGoalRecommendations({
    required List<GoalModel> goals,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    String? financialPersona,
  }) async {
    if (!_geminiAvailable || goals.isEmpty) {
      _goalRecommendations = _buildLocalGoalSummary(goals);
      notifyListeners();
      return;
    }

    _geminiLoadingCount++;
    notifyListeners();

    final response = await GeminiService.generateGoalRecommendations(
      goals: goals, incomes: incomes, expenses: expenses, budgets: budgets,
      financialPersona: financialPersona,
    );

    _geminiLoadingCount--;
    if (_geminiLoadingCount < 0) _geminiLoadingCount = 0;

    if (response.isFromFallback || response.content.isEmpty) {
      _goalRecommendations = _buildLocalGoalSummary(goals);
      notifyListeners();
      return;
    }

    _goalRecommendations = response.content;
    notifyListeners();
  }

    Future<GeminiResponse> chat({
    required String message,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    // ALWAYS attempt Gemini first. Gemini is the PRIMARY engine.
    // Local AI is ONLY used when Gemini actually fails.
    final response = await GeminiService.chat(
      message: message,
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      healthScore: _healthScore?.score,
      history: _chatHistory,
      financialPersona: financialPersona,
    );

    // If Gemini failed, fall back to Local AI.
    if (response.isFromFallback || response.content.isEmpty) {
      debugPrint('AIProvider: Gemini failed, falling back to Local AI. '
          'Error: ${response.errorMessage ?? 'unknown'}');
      final localResponse = _buildLocalChatResponse(
        message,
        incomes: incomes,
        expenses: expenses,
        budgets: budgets,
        goals: goals,
      );
      return GeminiResponse(
        content: localResponse,
        isFromFallback: true,
        errorMessage: response.errorMessage ?? 'Using Local AI temporarily.',
        errorType: response.errorType,
      );
    }

    return response;
  }

  // ===== CHAT ASSISTANT =====

  Future<String> sendChatMessage({
    required String message,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    _isChatLoading = true;
    notifyListeners();

    final response = await chat(
      message: message,
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      financialPersona: financialPersona,
    );

    _isChatLoading = false;
    _lastChatWasFallback = response.isFromFallback;

    // Save to Firestore history
    final ti = incomes.fold(0.0, (s, i) => s + i.amount);
    final te = expenses.fold(0.0, (s, e) => s + e.amount);
    await _chatHistoryService.saveMessage(
      question: message,
      response: response.content,
      contextSnapshot: {
        'totalIncome': ti,
        'totalExpense': te,
        'healthScore': _healthScore?.score ?? 0,
        'expenseCount': expenses.length,
        'budgetCount': budgets.length,
        'goalCount': goals.length,
      },
    );

    notifyListeners();
    return response.content;
  }

  void subscribeToChatHistory() {
    _chatHistoryService.getChatHistory().listen((messages) {
      _chatHistory = messages;
      notifyListeners();
    });
  }

  Future<void> deleteChatMessage(String messageId) async {
    await _chatHistoryService.deleteMessage(messageId);
  }

  Future<void> clearChatHistory() async {
    await _chatHistoryService.clearAllHistory();
  }

  // ===== BUDGET & WALLET ALERTS =====

  /// Check budget spending against limits and trigger notifications at 80%, 90%, 100%.
  Future<void> checkBudgetAlerts(List<BudgetModel> budgets) async {
    for (final budget in budgets) {
      if (budget.budgetAmount <= 0) continue;
      final percentage = (budget.spentAmount / budget.budgetAmount) * 100;

      if (percentage >= 100) {
        await NotificationService.showBudgetAlert(
          category: budget.category,
          spent: budget.spentAmount,
          budget: budget.budgetAmount,
          percentage: percentage,
        );
      } else if (percentage >= 90) {
        await NotificationService.showBudgetAlert(
          category: budget.category,
          spent: budget.spentAmount,
          budget: budget.budgetAmount,
          percentage: percentage,
        );
      } else if (percentage >= 80) {
        await NotificationService.showBudgetAlert(
          category: budget.category,
          spent: budget.spentAmount,
          budget: budget.budgetAmount,
          percentage: percentage,
        );
      }
    }
  }

  /// Check wallet balances and trigger low balance / limit exceeded notifications.
  Future<void> checkWalletAlerts(List<WalletModel> wallets) async {
    for (final wallet in wallets) {
      // Low balance warning (below ₹500)
      if (wallet.currentBalance <= 500 && wallet.currentBalance > 0) {
        await NotificationService.showWalletLowBalanceAlert(
          walletName: wallet.name,
          balance: wallet.currentBalance,
        );
      }
    }
  }

  // ===== CACHE =====
  Future<void> clearAICache() async {
    await AICacheService.clearCache();
  }

  // ===== FULL ANALYSIS =====

  Future<void> runFullAnalysis({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      // Local AI (always runs) — batch computations to avoid multiple rebuilds.
      _prediction = SpendingPredictor.predict(expenses);
      _suggestions = SavingsSuggester.generate(
        incomes: incomes, expenses: expenses, budgets: budgets,
      );
      _healthScore = FinancialHealthScoreCalculator.calculate(
        incomes: incomes, expenses: expenses, goals: goals, budgets: budgets,
      );
      _subscriptions = SubscriptionDetector.detect(expenses);
      _goalPlans = [];
      for (final goal in goals) {
        final plan = GoalPlanner.analyze(goal: goal, incomes: incomes, expenses: expenses);
        if (plan != null) _goalPlans.add(plan);
      }
      // Single notify after all local computations complete.
      notifyListeners();

      // Insights generation (runs on background isolate, notifies on completion).
      await generateInsights(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      );

      // Gemini (parallel, with automatic local AI fallback)
      if (_geminiAvailable) {
        await Future.wait([
          generateGeminiInsights(incomes: incomes, expenses: expenses, budgets: budgets, goals: goals, financialPersona: financialPersona),
          generateMonthlySummary(incomes: incomes, expenses: expenses, budgets: budgets, goals: goals, financialPersona: financialPersona),
          generateGoalRecommendations(goals: goals, incomes: incomes, expenses: expenses, budgets: budgets, financialPersona: financialPersona),
        ]);
      }

      // Trigger budget across-limit phone notifications using live budget data.
      // Uses a stable per-category notification id so repeated checks replace
      // rather than duplicate the pending notification.
      await checkBudgetAlerts(budgets);

      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _isAnalyzing = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // ===== LOCAL AI FALLBACK HELPERS =====

  String _buildLocalInsight(
    List<IncomeModel> incomes,
    List<ExpenseModel> expenses,
    List<BudgetModel> budgets,
    List<GoalModel> goals,
  ) {
    final ti = incomes.fold(0.0, (s, i) => s + i.amount);
    final te = expenses.fold(0.0, (s, e) => s + e.amount);
    final savings = ti - te;
    final savingsRate = ti > 0 ? ((savings / ti) * 100).toStringAsFixed(1) : '0';

    final sb = StringBuffer();
    sb.writeln('=== Financial Overview ===');
    sb.writeln('Income: Rs. ${ti.toStringAsFixed(0)}');
    sb.writeln('Expenses: Rs. ${te.toStringAsFixed(0)}');
    sb.writeln('Savings: Rs. ${savings.toStringAsFixed(0)} ($savingsRate% of income)');
    sb.writeln('');

    // Top category
    if (expenses.isNotEmpty) {
      final catTotals = <String, double>{};
      for (final e in expenses) {
        catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
      }
      final top = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct = ((top.value / te) * 100).toStringAsFixed(0);
      sb.writeln('Top spending: ${top.key} (Rs. ${top.value.toStringAsFixed(0)}, $pct% of total)');
    }

    // Budget status
    for (final b in budgets) {
      if (b.isExceeded) {
        sb.writeln('⚠️ ${b.category} budget exceeded by Rs. ${(b.spentAmount - b.budgetAmount).toStringAsFixed(0)}');
      }
    }

    // Goal progress
    for (final g in goals) {
      sb.writeln('🎯 ${g.title}: ${(g.progress * 100).toStringAsFixed(0)}% complete');
    }

    return sb.toString().trim();
  }

  String _buildLocalSummary(
    List<IncomeModel> incomes,
    List<ExpenseModel> expenses,
  ) {
    final ti = incomes.fold(0.0, (s, i) => s + i.amount);
    final te = expenses.fold(0.0, (s, e) => s + e.amount);
    return 'Income: Rs. ${ti.toStringAsFixed(0)} | Expenses: Rs. ${te.toStringAsFixed(0)} | Balance: Rs. ${(ti - te).toStringAsFixed(0)}';
  }

  String _buildLocalGoalSummary(List<GoalModel> goals) {
    if (goals.isEmpty) return 'No goals set yet. Start by creating a savings goal!';
    final sb = StringBuffer();
    for (final goal in goals) {
      final remaining = goal.targetAmount - goal.savedAmount;
      sb.writeln('${goal.title}: ${(goal.progress * 100).toStringAsFixed(0)}% complete, Rs. ${remaining.toStringAsFixed(0)} remaining');
    }
    return sb.toString().trim();
  }

  String _buildLocalChatResponse(
    String message, {
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final msg = message.toLowerCase();

    // Check for common financial questions and provide local AI responses
    if (msg.contains('save') || msg.contains('saving')) {
      final suggestions = SavingsSuggester.generate(
        incomes: incomes, expenses: expenses, budgets: budgets,
      );
      if (suggestions.isNotEmpty) {
        final sb = StringBuffer('Here are some savings suggestions based on your data:\n');
        for (final s in suggestions.take(3)) {
          sb.writeln('• ${s.title}: ${s.description} (Save ~Rs. ${s.potentialSavings.toStringAsFixed(0)})');
        }
        return sb.toString().trim();
      }
      return 'Based on your data, I recommend tracking your expenses and setting up a budget to identify saving opportunities.';
    }

    if (msg.contains('spend') || msg.contains('expense') || msg.contains('overspend')) {
      final te = expenses.fold(0.0, (s, e) => s + e.amount);
      final ti = incomes.fold(0.0, (s, i) => s + i.amount);

      if (expenses.isNotEmpty) {
        final catTotals = <String, double>{};
        for (final e in expenses) {
          catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
        }
        final top = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        final pct = ((top.value / te) * 100).toStringAsFixed(0);
        return 'Your total expenses are Rs. ${te.toStringAsFixed(0)}. Your top spending category is ${top.key} (Rs. ${top.value.toStringAsFixed(0)}, $pct% of expenses). ${ti > te ? "You're within your income." : "Consider reducing expenses to stay within your income."}';
      }
      return 'You have no expenses recorded yet.';
    }

    if (msg.contains('budget')) {
      if (budgets.isEmpty) {
        return 'You have no budgets set. Consider creating budgets for your main spending categories to track your spending.';
      }
      final sb = StringBuffer('Your budgets:\n');
      for (final b in budgets) {
        final status = b.isExceeded ? '⚠️ Exceeded' : '✓ On track';
        sb.writeln('• ${b.category}: Rs. ${b.spentAmount.toStringAsFixed(0)} / Rs. ${b.budgetAmount.toStringAsFixed(0)} ($status)');
      }
      return sb.toString().trim();
    }

    if (msg.contains('goal')) {
      if (goals.isEmpty) {
        return 'You have no savings goals yet. Create a goal to start saving towards something important!';
      }
      final sb = StringBuffer('Your savings goals:\n');
      for (final g in goals) {
        sb.writeln('• ${g.title}: ${(g.progress * 100).toStringAsFixed(0)}% complete (Rs. ${g.savedAmount.toStringAsFixed(0)} / Rs. ${g.targetAmount.toStringAsFixed(0)})');
      }
      return sb.toString().trim();
    }

    if (msg.contains('income')) {
      final ti = incomes.fold(0.0, (s, i) => s + i.amount);
      if (incomes.isEmpty) return 'You have no income recorded yet.';
      final sb = StringBuffer('Your income sources:\n');
      for (final i in incomes) {
        sb.writeln('• Rs. ${i.amount.toStringAsFixed(0)}${i.source.isNotEmpty ? ' (${i.source})' : ''}');
      }
      sb.writeln('\nTotal: Rs. ${ti.toStringAsFixed(0)}');
      return sb.toString().trim();
    }

    if (msg.contains('health') || msg.contains('score')) {
      if (_healthScore != null) {
        return 'Your financial health score is ${_healthScore!.score}/100 (${_healthScore!.label}). ${_healthScore!.reasons.isNotEmpty ? _healthScore!.reasons.first : "Keep up the good work!"}';
      }
      return 'Run a full analysis to see your financial health score.';
    }

    if (msg.contains('subscription')) {
      final subs = SubscriptionDetector.detect(expenses);
      if (subs.isEmpty) return 'No recurring subscriptions detected in your expenses.';
      final sb = StringBuffer('Detected subscriptions:\n');
      double total = 0;
      for (final s in subs) {
        sb.writeln('• ${s.name}: Rs. ${s.monthlyCost.toStringAsFixed(0)}/month');
        total += s.monthlyCost;
      }
      sb.writeln('\nTotal: Rs. ${total.toStringAsFixed(0)}/month');
      return sb.toString().trim();
    }

    // General response
    final ti = incomes.fold(0.0, (s, i) => s + i.amount);
    final te = expenses.fold(0.0, (s, e) => s + e.amount);
    return 'I\'m your SpendSense AI assistant (running in local mode). I can help with:\n'
        '• Saving tips and suggestions\n'
        '• Spending analysis and insights\n'
        '• Budget overview and tracking\n'
        '• Goal progress updates\n'
        '• Subscription detection\n'
        '• Financial health assessment\n\n'
        'Your current financial status — Income: Rs. ${ti.toStringAsFixed(0)}, Expenses: Rs. ${te.toStringAsFixed(0)}, Balance: Rs. ${(ti - te).toStringAsFixed(0)}.\n'
        'What would you like to know more about?';
  }

  Map<String, double> getSuggestedGoalAmounts() {
    return GoalPlanner.getSuggestedGoalAmounts();
  }

  void clearGeminiError() {
    _geminiErrorMessage = '';
    notifyListeners();
  }
}