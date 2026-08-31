import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/ai_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/income_model.dart';
import '../../models/expense_model.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';
import '../../services/ai/ai_insights_service.dart';
import '../../services/ai/savings_suggester.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shimmer_loading.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  bool _isLoading = false;
  DateTime? _lastUpdated;
  String? _dataHash;
  Map<String, dynamic>? _cachedInsights;

  // Precomputed values to avoid heavy calculations in build()
  String _todayInsight = '';
  String _weeklyInsight = '';
  String _monthlyInsight = '';
  List<Map<String, dynamic>> _financialTips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sw = Stopwatch()..start();
    debugPrint('[START] Savings Insights');

    final incomeProvider = context.read<IncomeProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();
    final aiProvider = context.read<AIProvider>();
    final userProvider = context.read<UserProvider>();

    final incomes = List.of(incomeProvider.incomeList);
    final expenses = List.of(expenseProvider.expenses);
    final budgets = List.of(budgetProvider.budgets);
    final goals = List.of(goalProvider.goals);

    setState(() {
      _isLoading = true;
    });

    try {
      // ===== FIRESTORE OPTIMIZATION =====
      final firestoreSw = Stopwatch()..start();
      debugPrint('[START] Firestore fetch');

      // Ensure providers are subscribed (they handle deduplication internally)
      // Run subscription setup in parallel
      await Future.wait([
        _safeSubscribe(incomeProvider),
        _safeSubscribe(expenseProvider),
        _safeSubscribe(budgetProvider),
        _safeSubscribe(goalProvider),
      ]);

      // Wait for initial data to arrive with proper timeout
      final dataReady = await _waitForInitialData(
        incomeProvider,
        expenseProvider,
        budgetProvider,
        goalProvider,
      );

      firestoreSw.stop();
      debugPrint('[END] Firestore fetch: ${firestoreSw.elapsedMilliseconds}ms');

      if (!dataReady) {
        debugPrint('[WARNING] Data not fully loaded, proceeding with available data');
      }

      // ===== LOCAL CALCULATIONS =====
      final localSw = Stopwatch()..start();
      debugPrint('[START] Local calculation');

      // Check cache - only recompute if data changed
      final currentHash = _generateDataHash(incomes, expenses, budgets, goals);

      if (_cachedInsights != null && _dataHash == currentHash) {
        debugPrint('[CACHE HIT] Using cached insights');
        // Use cached data
      } else {
        debugPrint('[CACHE MISS] Computing new insights');
        // Run local AI computations in parallel
        await _computeLocalInsights(
          aiProvider: aiProvider,
          incomes: incomes,
          expenses: expenses,
          budgets: budgets,
          goals: goals,
        );

        // Cache the results
        _dataHash = currentHash;
        _cachedInsights = {
          'insights': aiProvider.insights,
          'suggestions': aiProvider.suggestions,
          'healthScore': aiProvider.healthScore,
          'subscriptions': aiProvider.subscriptions,
          'goalPlans': aiProvider.goalPlans,
        };
      }

      localSw.stop();
      debugPrint('[END] Local calculation: ${localSw.elapsedMilliseconds}ms');

      // ===== GEMINI =====
      final geminiSw = Stopwatch()..start();
      debugPrint('[START] Gemini request');

      if (aiProvider.isGeminiConfigured) {
        try {
          // Gemini with timeout to prevent UI freeze
          await _computeGeminiInsights(
            aiProvider: aiProvider,
            incomes: incomes,
            expenses: expenses,
            budgets: budgets,
            goals: goals,
            financialPersona: userProvider.persona,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[TIMEOUT] Gemini request timed out after 10s');
              return;
            },
          );
        } catch (e) {
          debugPrint('[GEMINI ERROR] ${e.toString()}');
          // Continue with local AI fallback
        }
      } else {
        debugPrint('[SKIP] Gemini not configured, using local AI only');
      }

      geminiSw.stop();
      debugPrint('[END] Gemini request: ${geminiSw.elapsedMilliseconds}ms');

      sw.stop();
      debugPrint('[END] Savings Insights: ${sw.elapsedMilliseconds}ms');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _lastUpdated = DateTime.now();
        _updateUIValues(aiProvider, incomeProvider, expenseProvider, budgets, goals);
      });
    } catch (e) {
      sw.stop();
      debugPrint('[ERROR] Savings Insights failed after ${sw.elapsedMilliseconds}ms: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _updateUIValues(aiProvider, incomeProvider, expenseProvider, budgets, goals);
      });
    }
  }

  /// Safely subscribe to provider (handles already-subscribed state)
  Future<void> _safeSubscribe(dynamic provider) async {
    if (provider is IncomeProvider) {
      provider.subscribe();
    } else if (provider is ExpenseProvider) {
      provider.subscribe();
    } else if (provider is BudgetProvider) {
      provider.subscribe();
    } else if (provider is GoalProvider) {
      provider.subscribe();
    }
  }

  /// Wait for initial data to arrive from Firestore
  Future<bool> _waitForInitialData(
    IncomeProvider incomeProvider,
    ExpenseProvider expenseProvider,
    BudgetProvider budgetProvider,
    GoalProvider goalProvider,
  ) async {
    const maxWait = Duration(seconds: 2);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWait) {
      // Check if we have data from at least income and expense providers
      if (incomeProvider.incomeList.isNotEmpty ||
          expenseProvider.expenses.isNotEmpty) {
        return true;
      }
      // Small delay before checking again
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Even if we don't have data yet, proceed (data will arrive via streams)
    return true;
  }

  /// Generate hash for cache invalidation
  String _generateDataHash(
    List<IncomeModel> incomes,
    List<ExpenseModel> expenses,
    List<BudgetModel> budgets,
    List<GoalModel> goals,
  ) {
    final incomeHash = incomes.length.toString() +
        incomes.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(2);
    final expenseHash = expenses.length.toString() +
        expenses.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(2);
    final budgetHash = budgets.length.toString() +
        budgets.fold(0.0, (s, b) => s + b.budgetAmount).toStringAsFixed(2);
    final goalHash = goals.length.toString() +
        goals.fold(0.0, (s, g) => s + g.targetAmount).toStringAsFixed(2);
    return '$incomeHash|$expenseHash|$budgetHash|$goalHash';
  }

  /// Run local AI computations in parallel
  Future<void> _computeLocalInsights({
    required AIProvider aiProvider,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) async {
    // Run all local AI computations in parallel
    await Future.wait([
      // Insights generation (runs on background isolate)
      Future(() => aiProvider.generateInsights(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
      )),
      // Savings suggestions
      Future(() => aiProvider.generateSuggestions(
        incomes: incomes, expenses: expenses, budgets: budgets,
      )),
      // Health score
      Future(() => aiProvider.calculateHealthScore(
        incomes: incomes, expenses: expenses, goals: goals, budgets: budgets,
      )),
      // Subscription detection
      Future(() => aiProvider.detectSubscriptions(expenses)),
      // Goal analysis
      Future(() => aiProvider.analyzeGoals(
        goals: goals, incomes: incomes, expenses: expenses,
      )),
    ]);
  }

  /// Run Gemini computations with timeout
  Future<void> _computeGeminiInsights({
    required AIProvider aiProvider,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    String? financialPersona,
  }) async {
    // Gemini is primary - attempt all Gemini calls in parallel
    await Future.wait([
      aiProvider.generateGeminiInsights(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        financialPersona: financialPersona,
      ),
      aiProvider.generateMonthlySummary(
        incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
        financialPersona: financialPersona,
      ),
      aiProvider.generateGoalRecommendations(
        goals: goals, incomes: incomes, expenses: expenses, budgets: budgets,
        financialPersona: financialPersona,
      ),
    ]);
  }

  void _updateUIValues(
    AIProvider aiProvider,
    IncomeProvider incomeProvider,
    ExpenseProvider expenseProvider,
    List<BudgetModel> budgets,
    List<GoalModel> goals,
  ) {
    _todayInsight = _buildTodayInsight(aiProvider, expenseProvider);
    _weeklyInsight = _buildWeeklyInsight(aiProvider, expenseProvider);
    _monthlyInsight = _buildMonthlyInsight(aiProvider, incomeProvider, expenseProvider);
    _financialTips = _buildFinancialTips(aiProvider, incomeProvider, expenseProvider, budgets, goals);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiProvider = context.watch<AIProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();
    final budgets = budgetProvider.budgets;
    final goals = goalProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        centerTitle: true,
        actions: [
          if (_lastUpdated != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  'Updated ${_formatLastUpdated(_lastUpdated!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh AI Insights',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading && aiProvider.insights.isEmpty
              ? _buildLoadingShimmer()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Insight
                      if (aiProvider.isGeminiLoading)
                        _buildGeminiLoadingCard(isDark)
                      else if (aiProvider.geminiInsight.isNotEmpty)
                        _buildGeminiInsightCard(context, aiProvider, isDark),

                      if (aiProvider.geminiErrorMessage.isNotEmpty)
                        _buildGeminiErrorCard(context, aiProvider, isDark),

                      const SizedBox(height: 16),
                      Text('Financial Insights',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Today's Insight
                      _buildInsightCard(context, "Today's Insight", Icons.today, const Color(0xFF6C63FF),
                        _todayInsight.isNotEmpty ? _todayInsight : _fallbackTodayInsight(aiProvider, context), isDark),
                      const SizedBox(height: 12),

                      // Weekly Insight
                      _buildInsightCard(context, 'Weekly Insight', Icons.date_range, const Color(0xFF00D9A6),
                        _weeklyInsight.isNotEmpty ? _weeklyInsight : _fallbackWeeklyInsight(aiProvider, context), isDark),
                      const SizedBox(height: 12),

                      // Monthly Insight
                      _buildInsightCard(context, 'Monthly Insight', Icons.calendar_month, const Color(0xFFFFB84D),
                        _monthlyInsight.isNotEmpty ? _monthlyInsight : _fallbackMonthlyInsight(context), isDark),
                      const SizedBox(height: 20),

                      // Financial Tips
                      Text('Financial Tips',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...(_financialTips.isNotEmpty ? _financialTips : _buildFinancialTips(aiProvider, context.read<IncomeProvider>(), context.read<ExpenseProvider>(), budgets, goals))
                          .map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.lightbulb_outline, color: Color(0xFF6C63FF), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tip['title'] as String,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(tip['description'] as String, style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),

                      // Savings Opportunities
                      if (aiProvider.suggestions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Savings Opportunities',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...aiProvider.suggestions.take(5).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: s.priority == SuggestionPriority.high
                                          ? const Color(0xFF00D9A6).withValues(alpha: 0.1)
                                          : const Color(0xFFFFB84D).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.savings,
                                      color: s.priority == SuggestionPriority.high
                                          ? const Color(0xFF00D9A6) : const Color(0xFFFFB84D), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        Text(s.description, style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Text('+₹${s.potentialSavings.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF00D9A6), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        )),
                      ],

                      // AI Insights list
                      if (aiProvider.insights.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('AI Generated Insights',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...aiProvider.insights.take(10).map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getInsightTypeColor(insight.type),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(insight.emoji, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(insight.title,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(insight.description,
                                          style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerLoading(height: 120, borderRadius: 16),
        SizedBox(height: 16),
        ShimmerLoading(height: 24, width: 180),
        SizedBox(height: 16),
        ShimmerLoading(height: 90, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerLoading(height: 90, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerLoading(height: 90, borderRadius: 16),
        SizedBox(height: 20),
        ShimmerLoading(height: 24, width: 140),
        SizedBox(height: 16),
        ShimmerLoading(height: 80, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerLoading(height: 80, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerLoading(height: 80, borderRadius: 16),
      ],
    );
  }

  Widget _buildGeminiLoadingCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('AI is analyzing your finances...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiInsightCard(BuildContext context, AIProvider aiProvider, bool isDark) {
    return GlassCard(
      gradient: LinearGradient(
        colors: [const Color(0xFF6C63FF).withValues(alpha: 0.2), const Color(0xFF6C63FF).withValues(alpha: 0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI-Powered Insight',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(aiProvider.geminiInsight, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiErrorCard(BuildContext context, AIProvider aiProvider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB84D).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB84D).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFFB84D), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(aiProvider.geminiErrorMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB84D)))),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, String title, IconData icon, Color color, String content, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(content, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTodayInsight(AIProvider aiProvider, ExpenseProvider expenseProvider) {
    if (aiProvider.insights.isNotEmpty) {
      final todayInsights = aiProvider.insights.where((i) => i.period == 'daily').toList();
      if (todayInsights.isNotEmpty) return '${todayInsights.first.emoji} ${todayInsights.first.title}: ${todayInsights.first.description}';
    }
    final now = DateTime.now();
    final todayExpenses = expenseProvider.expenses.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
        .fold<double>(0, (sum, e) => sum + e.amount);
    if (todayExpenses > 0) return 'You\'ve spent ₹${todayExpenses.toStringAsFixed(0)} today. ${todayExpenses > 1000 ? 'Consider tracking your daily expenses closely.' : 'Keep up the good control!'}';
    return 'No expenses recorded today. Great job staying mindful of your spending!';
  }

  String _fallbackTodayInsight(AIProvider aiProvider, BuildContext context) {
    return _buildTodayInsight(aiProvider, context.read<ExpenseProvider>());
  }

  String _buildWeeklyInsight(AIProvider aiProvider, ExpenseProvider expenseProvider) {
    if (aiProvider.prediction != null) {
      final p = aiProvider.prediction!;
      return 'Predicted weekly spending: ₹${p.nextWeek.toStringAsFixed(0)}. Monthly prediction: ₹${p.nextMonth.toStringAsFixed(0)}. Confidence: ${(p.confidence * 100).toStringAsFixed(0)}%';
    }
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklyExpenses = expenseProvider.expenses.where((e) => e.date.isAfter(weekAgo))
        .fold<double>(0, (sum, e) => sum + e.amount);
    return 'You\'ve spent ₹${weeklyExpenses.toStringAsFixed(0)} in the last 7 days.';
  }

  String _fallbackWeeklyInsight(AIProvider aiProvider, BuildContext context) {
    return _buildWeeklyInsight(aiProvider, context.read<ExpenseProvider>());
  }

  String _buildMonthlyInsight(AIProvider aiProvider, IncomeProvider incomeProvider, ExpenseProvider expenseProvider) {
    if (aiProvider.monthlySummary.isNotEmpty) return aiProvider.monthlySummary;
    final now = DateTime.now();
    final monthlyIncome = incomeProvider.incomeList.where((i) => i.date.month == now.month && i.date.year == now.year)
        .fold<double>(0, (sum, i) => sum + i.amount);
    final monthlyExpenses = expenseProvider.expenses.where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final balance = monthlyIncome - monthlyExpenses;
    return 'Monthly Summary: Income: ₹${monthlyIncome.toStringAsFixed(0)}, Expenses: ₹${monthlyExpenses.toStringAsFixed(0)}, Balance: ₹${balance.toStringAsFixed(0)}';
  }

  String _fallbackMonthlyInsight(BuildContext context) {
    return _buildMonthlyInsight(context.read<AIProvider>(), context.read<IncomeProvider>(), context.read<ExpenseProvider>());
  }

  List<Map<String, dynamic>> _buildFinancialTips(
    AIProvider aiProvider,
    IncomeProvider incomeProvider,
    ExpenseProvider expenseProvider,
    List<BudgetModel> budgets,
    List<GoalModel> goals,
  ) {
    final tips = <Map<String, dynamic>>[];
    final totalIncome = incomeProvider.totalIncome;
    final totalExpense = expenseProvider.totalExpense;

    if (totalIncome > 0) {
      if (totalExpense > totalIncome * 0.8) {
        tips.add({
          'title': 'Overspending Warning',
          'description': 'Your expenses are ${((totalExpense / totalIncome) * 100).toStringAsFixed(0)}% of your income. Try to keep expenses below 70% to maintain healthy savings.',
        });
      } else if (totalExpense < totalIncome * 0.5) {
        tips.add({
          'title': 'Excellent Savings Rate',
          'description': 'You\'re saving more than 50% of your income! Consider investing the surplus for long-term growth.',
        });
      }
    }

    if (aiProvider.suggestions.isNotEmpty) {
      final topSuggestion = aiProvider.suggestions.first;
      tips.add({
        'title': 'Top Savings Tip',
        'description': '${topSuggestion.title}: ${topSuggestion.description}. Potential savings: ₹${topSuggestion.potentialSavings.toStringAsFixed(0)}',
      });
    }

    if (aiProvider.subscriptions.isNotEmpty) {
      final totalSubs = aiProvider.totalMonthlySubscriptions;
      tips.add({
        'title': 'Subscription Alert',
        'description': 'You have ${aiProvider.subscriptions.length} active subscriptions totaling ₹${totalSubs.toStringAsFixed(0)}/month. Review and cancel unused ones.',
      });
    }

    // Budget utilization tips
    for (final budget in budgets.take(3)) {
      if (budget.isExceeded) {
        tips.add({
          'title': 'Budget Exceeded: ${budget.category}',
          'description': 'You\'ve exceeded your ${budget.category} budget of ₹${budget.budgetAmount.toStringAsFixed(0)} by ₹${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(0)}. Consider adjusting your spending.',
        });
        break;
      }
    }

    // Goal progress tips
    for (final goal in goals.take(2)) {
      if (goal.progress >= 0.9 && goal.progress < 1.0) {
        tips.add({
          'title': 'Almost There: ${goal.title}',
          'description': 'Your goal is ${(goal.progress * 100).toStringAsFixed(0)}% complete! Just ₹${(goal.targetAmount - goal.savedAmount).toStringAsFixed(0)} to go.',
        });
      }
    }

    if (tips.isEmpty) {
      tips.add({
        'title': 'General Tip',
        'description': 'Track every expense, set a monthly budget, and aim to save at least 20% of your income for financial security.',
      });
    }
    return tips;
  }

  String _formatLastUpdated(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  Color _getInsightTypeColor(InsightType type) {
    switch (type) {
      case InsightType.positive: return const Color(0xFF00D9A6).withValues(alpha: 0.15);
      case InsightType.warning: return const Color(0xFFFFB84D).withValues(alpha: 0.15);
      case InsightType.negative: return const Color(0xFFFF6584).withValues(alpha: 0.15);
      default: return const Color(0xFF6C63FF).withValues(alpha: 0.15);
    }
  }
}