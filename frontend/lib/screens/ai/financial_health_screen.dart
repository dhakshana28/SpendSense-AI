import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/ai_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/ai/savings_suggester.dart';
import '../../widgets/glass_card.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    context.read<IncomeProvider>().subscribe();
    context.read<ExpenseProvider>().subscribe();
    context.read<BudgetProvider>().subscribe();
    context.read<GoalProvider>().subscribe();

    final aiProvider = context.read<AIProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();

    aiProvider.calculateHealthScore(
      incomes: incomeProvider.incomeList,
      expenses: expenseProvider.expenses,
      goals: goalProvider.goals,
      budgets: budgetProvider.budgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();
    final incomeProvider = context.watch<IncomeProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final goalProvider = context.watch<GoalProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final healthScore = aiProvider.healthScore;
    final scoreValue = healthScore?.score ?? 0;
    final scoreColor = scoreValue >= 80
        ? const Color(0xFF00D9A6)
        : scoreValue >= 60
            ? const Color(0xFFFFB84D)
            : const Color(0xFFFF6584);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Score',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Score Card
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      scoreColor.withValues(alpha: 0.3),
                      scoreColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Overall Health Score',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    healthScore?.label ?? 'Calculating...',
                                    style: TextStyle(
                                      color: scoreColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scoreColor.withValues(alpha: 0.2),
                                border: Border.all(color: scoreColor, width: 4),
                              ),
                              child: Center(
                                child: Text(
                                  '$scoreValue',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (healthScore != null) ...[
                          const SizedBox(height: 8),
                          ...healthScore.reasons.map((reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: reason.startsWith('✓') ? const Color(0xFF00D9A6) :
                                           reason.startsWith('✗') ? const Color(0xFFFF6584) :
                                           const Color(0xFFFFB84D),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],

                        const SizedBox(height: 16),
                        if (healthScore != null)
                          Text(
                            healthScore.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Score Breakdown
                Text(
                  'Score Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Income',
                        value: '₹${incomeProvider.totalIncome.toStringAsFixed(0)}',
                        icon: Icons.arrow_downward,
                        color: const Color(0xFF00D9A6),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Expenses',
                        value: '₹${expenseProvider.totalExpense.toStringAsFixed(0)}',
                        icon: Icons.arrow_upward,
                        color: const Color(0xFFFF6584),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Active Budgets',
                        value: '${budgetProvider.budgets.length}',
                        icon: Icons.pie_chart,
                        color: const Color(0xFF6C63FF),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Active Goals',
                        value: '${goalProvider.goals.length}',
                        icon: Icons.flag,
                        color: const Color(0xFFFFB84D),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // AI Recommendations
                if (aiProvider.suggestions.isNotEmpty) ...[
                  Text(
                    'AI Recommendations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...aiProvider.suggestions.take(5).map((s) => Padding(
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
                                color: s.priority == SuggestionPriority.high
                                    ? const Color(0xFF00D9A6).withValues(alpha: 0.1)
                                    : const Color(0xFFFFB84D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.rocket_launch,
                                color: s.priority == SuggestionPriority.high
                                    ? const Color(0xFF00D9A6)
                                    : const Color(0xFFFFB84D),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.description,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
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
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}