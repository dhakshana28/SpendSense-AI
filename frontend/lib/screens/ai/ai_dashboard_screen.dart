import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/ai_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_card.dart';
import '../ai_chat_screen.dart';
import 'ai_insights_screen.dart';
import 'financial_health_screen.dart';
import 'ai_alerts_screen.dart';
import '../bank_statement_import_screen.dart';
import 'subscription_detail_screen.dart';
import '../../services/ai/health_score.dart';
import '../../services/ai/savings_suggester.dart';
import '../../services/ai/subscription_detector.dart';
import '../../services/ai/spending_predictor.dart';
import '../../services/ai/goal_planner.dart';

class AIDashboardScreen extends StatefulWidget {
  const AIDashboardScreen({super.key});

  @override
  State<AIDashboardScreen> createState() => _AIDashboardScreenState();
}

class _AIDashboardScreenState extends State<AIDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final aiProvider = context.read<AIProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();
    final userProvider = context.read<UserProvider>();

    incomeProvider.subscribe();
    expenseProvider.subscribe();
    budgetProvider.subscribe();
    goalProvider.subscribe();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    aiProvider.runFullAnalysis(
      incomes: incomeProvider.incomeList,
      expenses: expenseProvider.expenses,
      budgets: budgetProvider.budgets,
      goals: goalProvider.goals,
      financialPersona: userProvider.persona,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthScore = ai.healthScore;
    final suggestions = ai.suggestions;
    final prediction = ai.prediction;
    final subscriptions = ai.subscriptions;
    final goalPlans = ai.goalPlans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Dashboard'),
        actions: [
          if (ai.isAnalyzing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh AI Analysis'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      _buildHeader(context, isDark),
                      const SizedBox(height: 20),
                      _buildHealthScoreCard(context, healthScore, isDark),
                      const SizedBox(height: 20),
                      _buildPrimaryFeatureGrid(context, isDark, isWide, ai, subscriptions, prediction, suggestions, goalPlans),
                      const SizedBox(height: 20),
                      _buildBankStatementCard(context, isDark),
                      const SizedBox(height: 12),
                      _buildAIChatCard(context, isDark),
                      const SizedBox(height: 20),
                      if (ai.isGeminiLoading)
                        _buildLoadingCard(context, isDark, 'Gemini AI is analyzing your finances...')
                      else if (ai.geminiInsight.isNotEmpty)
                        _buildGeminiInsightCard(context, ai, isDark),
                      if (ai.geminiErrorMessage.isNotEmpty && !ai.isGeminiLoading)
                        _buildGeminiErrorCard(context, ai, isDark),
                      if (suggestions.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Savings Opportunities', Icons.savings),
                        const SizedBox(height: 8),
                        ...suggestions.take(3).map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildSuggestionCard(context, s, isDark))),
                        const SizedBox(height: 12),
                      ],
                      if (subscriptions.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Detected Subscriptions', Icons.subscriptions),
                        const SizedBox(height: 8),
                        ...subscriptions.take(3).map((sub) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildSubscriptionListItem(context, sub, isDark))),
                        if (subscriptions.length > 3)
                          TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionDetailScreen())),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text('View all ${subscriptions.length} subscriptions'),
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (prediction != null) ...[
                        _buildSectionTitle(context, 'Spending Prediction', Icons.trending_up),
                        const SizedBox(height: 8),
                        _buildPredictionCard(context, prediction, isDark),
                        const SizedBox(height: 12),
                      ],
                      if (goalPlans.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Goal Recommendations', Icons.flag),
                        const SizedBox(height: 8),
                        ...goalPlans.take(2).map((g) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildGoalPlanCard(context, g, isDark))),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(height: 4),
        Text('Your financial intelligence at a glance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHealthScoreCard(BuildContext context, HealthScoreResult? health, bool isDark) {
    final score = health?.score ?? 0;
    final label = health?.label ?? 'N/A';
    return GlassCard(
      gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
            child: Center(child: Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Financial Health', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(health != null && health.reasons.isNotEmpty ? health.reasons.first : 'Analysis in progress...',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPrimaryFeatureGrid(BuildContext context, bool isDark, bool isWide, AIProvider ai,
      List<DetectedSubscription> subscriptions, SpendingPrediction? prediction,
      List<SavingsSuggestion> suggestions, List<GoalPlan> goalPlans) {
    final features = [
      _AIFeatureItem('Financial Health', Icons.favorite, const Color(0xFF00D9A6),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialHealthScreen())),
          value: ai.healthScore != null ? '${ai.healthScore!.score}/100' : '--',
          subtitle: ai.healthScore?.label ?? 'Tap to analyze'),
      _AIFeatureItem('Spending Prediction', Icons.trending_up, const Color(0xFFFFB84D),
          () => _showPredictionDetail(context, prediction),
          value: prediction != null ? '₹${prediction.nextMonth.toStringAsFixed(0)}' : '--',
          subtitle: prediction != null ? 'Next month estimate' : 'Tap to predict'),
      _AIFeatureItem('Savings Insights', Icons.savings, const Color(0xFF6C63FF),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIInsightsScreen())),
          value: '${suggestions.length} tips',
          subtitle: suggestions.isNotEmpty ? suggestions.first.title : 'Tap for insights'),
      _AIFeatureItem('Subscriptions', Icons.subscriptions, const Color(0xFFFF6584),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionDetailScreen())),
          value: '${subscriptions.length} active',
          subtitle: subscriptions.isNotEmpty
              ? '₹${SubscriptionDetector.totalMonthlyCost(subscriptions).toStringAsFixed(0)}/mo'
              : 'Tap to detect'),
      _AIFeatureItem('Goal Recommendations', Icons.flag, const Color(0xFF00A3FF),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIInsightsScreen())),
          value: '${goalPlans.length} plans',
          subtitle: goalPlans.isNotEmpty ? goalPlans.first.goalTitle : 'Tap to plan'),
      _AIFeatureItem('AI Insights', Icons.auto_awesome, const Color(0xFF8B5CF6),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIInsightsScreen())),
          value: ai.isGeminiLoading ? 'Analyzing...' : (ai.geminiInsight.isNotEmpty ? 'Ready' : 'Tap'),
          subtitle: ai.isGeminiLoading ? 'Please wait' : (ai.geminiInsight.isNotEmpty ? 'AI-powered' : 'Tap for AI')),
      _AIFeatureItem('AI Alerts', Icons.notifications_active, const Color(0xFFFF5757),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAlertsScreen())),
          value: 'Live alerts',
          subtitle: 'Budget, goals & alerts'),
    ];

    return LayoutBuilder(
      builder: (context, gridConstraints) {
        // Content-driven adaptive grid (Wrap) instead of a fixed-aspect GridView.
        // This prevents vertical overflow on narrow mobile screens where a fixed
        // childAspectRatio would produce tiles shorter than their content.
        final columns = gridConstraints.maxWidth > 600 ? 3 : 2;
        final tileWidth =
            (gridConstraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final f in features)
              SizedBox(
                width: tileWidth,
                child: GlassCard(
                  onTap: f.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: f.color.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(f.icon, color: f.color, size: 20),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white38 : Colors.black26),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(f.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(f.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: f.color)),
                        const SizedBox(height: 2),
                        Text(f.subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }


  Widget _buildBankStatementCard(BuildContext context, bool isDark) {
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankStatementImportScreen())),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF00A3FF).withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.upload_file, color: Color(0xFF00A3FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analyze Bank Statement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Upload PDF, CSV or Excel and automatically analyze your transactions.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00A3FF), Color(0xFF0099FF)]), borderRadius: BorderRadius.circular(20)),
              child: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIChatCard(BuildContext context, bool isDark) {
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.chat, color: Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Financial Assistant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Ask anything about your spending, budget and financial goals.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)]), borderRadius: BorderRadius.circular(20)),
              child: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, bool isDark, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(message, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }

Widget _buildGeminiInsightCard(BuildContext context, AIProvider ai, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
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
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI-Powered Insight', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Text(ai.geminiInsight, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiErrorCard(BuildContext context, AIProvider ai, bool isDark) {
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
            Expanded(child: Text(ai.geminiErrorMessage, style: const TextStyle(color: Color(0xFFFFB84D)))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSuggestionCard(BuildContext context, SavingsSuggestion s, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.priority == SuggestionPriority.high ? const Color(0xFF00D9A6).withValues(alpha: 0.1) : const Color(0xFFFFB84D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.savings, color: s.priority == SuggestionPriority.high ? const Color(0xFF00D9A6) : const Color(0xFFFFB84D), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(s.description, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Text('+₹${s.potentialSavings.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF00D9A6), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionListItem(BuildContext context, DetectedSubscription sub, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionDetailScreen())),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFFF6584).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.subscriptions, color: Color(0xFFFF6584)),
        ),
        title: Text(sub.name, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text('Monthly: ₹${sub.monthlyCost.toStringAsFixed(0)}${sub.isUnused ? ' • Unused' : ''}',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
        trailing: Text('₹${sub.monthlyCost.toStringAsFixed(0)}/mo', style: const TextStyle(color: Color(0xFFFF6584), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPredictionCard(BuildContext context, SpendingPrediction prediction, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Predicted Next Month', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('₹${prediction.nextMonth.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFB84D), borderRadius: BorderRadius.circular(20)),
                  child: Text('${prediction.confidence >= 0.5 ? 'Moderate' : 'Low'} Confidence',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMiniStat(context, 'Next Week', '₹${prediction.nextWeek.toStringAsFixed(0)}', isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildMiniStat(context, 'Next Month', '₹${prediction.nextMonth.toStringAsFixed(0)}', isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalPlanCard(BuildContext context, GoalPlan plan, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.flag, color: Color(0xFF6C63FF)),
        title: Text(plan.goalTitle, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(plan.suggestion, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
        trailing: Text('${(plan.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }


  void _showPredictionDetail(BuildContext context, SpendingPrediction? prediction) {
    if (prediction == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spending Prediction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next Week: ₹${prediction.nextWeek.toStringAsFixed(0)}'),
            Text('Next Month: ₹${prediction.nextMonth.toStringAsFixed(0)}'),
            Text('Confidence: ${(prediction.confidence * 100).toStringAsFixed(0)}%'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _AIFeatureItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String value;
  final String subtitle;

  const _AIFeatureItem(this.title, this.icon, this.color, this.onTap, {required this.value, required this.subtitle});
}


