import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/ai_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_card.dart';

class AIAlertsScreen extends StatefulWidget {
  const AIAlertsScreen({super.key});

  @override
  State<AIAlertsScreen> createState() => _AIAlertsScreenState();
}

class _AIAlertsScreenState extends State<AIAlertsScreen> {
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

    aiProvider.generateInsights(
      incomes: incomeProvider.incomeList,
      expenses: expenseProvider.expenses,
      budgets: budgetProvider.budgets,
      goals: goalProvider.goals,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final budgetProvider = context.watch<BudgetProvider>();

    final alerts = _buildAlerts(aiProvider, expenseProvider, budgetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Alerts',
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
                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF6584).withValues(alpha: 0.2),
                        const Color(0xFFFFB84D).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6584).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active, color: Color(0xFFFF6584), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${alerts.length} Active Alerts',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Review and take action',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Alerts List
                if (alerts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: const Color(0xFF00D9A6).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All clear!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No alerts at this time. Keep up the good work!',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...alerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AlertCard(
                      title: alert['title'] as String,
                      description: alert['description'] as String,
                      priority: alert['priority'] as String,
                      icon: alert['icon'] as IconData,
                      color: alert['color'] as Color,
                      onTap: alert['onTap'] as VoidCallback?,
                    ),
                  )),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildAlerts(
    AIProvider aiProvider,
    ExpenseProvider expenseProvider,
    BudgetProvider budgetProvider,
  ) {
    final alerts = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final incomeProvider = context.read<IncomeProvider>();
    final totalIncome = incomeProvider.totalIncome;
    final totalExpense = expenseProvider.totalExpense;

    // Budget Alerts
    for (final budget in budgetProvider.budgets) {
      if (budget.isExceeded) {
        alerts.add({
          'title': 'Budget Exceeded: ${budget.category}',
          'description': 'Your ${budget.category} budget of ₹${budget.budgetAmount.toStringAsFixed(0)} has been exceeded by ₹${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(0)}.',
          'priority': 'high',
          'icon': Icons.warning_rounded,
          'color': const Color(0xFFFF4757),
          'onTap': () => Navigator.pushNamed(context, '/budget'),
        });
      } else if (budget.spentAmount > budget.budgetAmount * 0.8) {
        final budgetProgress = budget.budgetAmount > 0 ? budget.spentAmount / budget.budgetAmount : 0;
        alerts.add({
          'title': 'Budget Warning: ${budget.category}',
          'description': 'You\'ve used ${(budgetProgress * 100).toStringAsFixed(0)}% of your ${budget.category} budget. ₹${budget.remainingAmount.toStringAsFixed(0)} remaining.',
          'priority': 'medium',
          'icon': Icons.warning_amber_rounded,
          'color': const Color(0xFFFFB84D),
          'onTap': () => Navigator.pushNamed(context, '/budget'),
        });
      }
    }

    // Large Expense Alerts
    final todayExpenses = expenseProvider.expenses.where((e) =>
      e.date.year == now.year && e.date.month == now.month && e.date.day == now.day
    ).toList();

    if (todayExpenses.isNotEmpty) {
      final todayTotal = todayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
      final avgDaily = totalIncome > 0 ? (totalExpense / 30) : 0;

      if (todayTotal > avgDaily * 2 && avgDaily > 0) {
        alerts.add({
          'title': 'Unusually High Spending Today',
          'description': 'You\'ve spent ₹${todayTotal.toStringAsFixed(0)} today, which is ${(todayTotal / avgDaily).toStringAsFixed(1)}x your average daily spending.',
          'priority': 'high',
          'icon': Icons.trending_up,
          'color': const Color(0xFFFF6584),
          'onTap': () => Navigator.pushNamed(context, '/expense'),
        });
      }

      final maxExpense = todayExpenses.reduce((a, b) => a.amount > b.amount ? a : b);
      if (maxExpense.amount > 5000) {
        alerts.add({
          'title': 'Large Expense Detected',
          'description': '₹${maxExpense.amount.toStringAsFixed(0)} spent on ${maxExpense.description.isNotEmpty ? maxExpense.description : maxExpense.category}.',
          'priority': 'medium',
          'icon': Icons.receipt_long,
          'color': const Color(0xFFFFB84D),
        });
      }
    }

    // Savings Alert
    if (totalIncome > 0) {
      final savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
      if (savingsRate < 0) {
        alerts.add({
          'title': 'Overspending Alert',
          'description': 'Your expenses exceeded your income by ₹${(-(totalIncome - totalExpense)).toStringAsFixed(0)}. Immediate action required!',
          'priority': 'high',
          'icon': Icons.error_outline,
          'color': const Color(0xFFFF4757),
          'onTap': () => Navigator.pushNamed(context, '/ai-insights'),
        });
      } else if (savingsRate < 20) {
        alerts.add({
          'title': 'Low Savings Rate',
          'description': 'Your savings rate is only ${savingsRate.toStringAsFixed(0)}%. Aim to save at least 20% of your income.',
          'priority': 'medium',
          'icon': Icons.savings_outlined,
          'color': const Color(0xFFFFB84D),
          'onTap': () => Navigator.pushNamed(context, '/ai-dashboard'),
        });
      }
    }

    // Subscription Alert
    if (aiProvider.subscriptions.isNotEmpty) {
      final totalMonthlySubs = aiProvider.totalMonthlySubscriptions;
      final annualSubs = totalMonthlySubs * 12;
      alerts.add({
        'title': 'Subscription Review',
        'description': 'You have ${aiProvider.subscriptions.length} active subscriptions (₹${totalMonthlySubs.toStringAsFixed(0)}/mo, ₹${annualSubs.toStringAsFixed(0)}/yr). Review unused ones.',
        'priority': 'medium',
        'icon': Icons.subscriptions,
        'color': const Color(0xFF845EF7),
        'onTap': () => Navigator.pushNamed(context, '/ai-dashboard'),
      });
    }

    // Goal Alert
    final goalProvider = context.read<GoalProvider>();
    for (final goal in goalProvider.goals) {
      final remaining = goal.targetAmount - goal.savedAmount;
      if (remaining <= 0) continue;

      final daysLeft = goal.targetDate.difference(now).inDays;

      if (daysLeft < 30 && goal.progress < 1.0) {
        alerts.add({
          'title': 'Goal Deadline Approaching: ${goal.title}',
          'description': 'Only ${daysLeft}d left! ₹${remaining.toStringAsFixed(0)} still needed. Current progress: ${(goal.progress * 100).toStringAsFixed(0)}%.',
          'priority': 'high',
          'icon': Icons.flag,
          'color': const Color(0xFFFF6584),
          'onTap': () => Navigator.pushNamed(context, '/goals'),
        });
      }
    }

    // Sort by priority
    alerts.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return (priorityOrder[a['priority']] ?? 1).compareTo(priorityOrder[b['priority']] ?? 1);
    });

    return alerts;
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String description;
  final String priority;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AlertCard({
    required this.title,
    required this.description,
    required this.priority,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
          ],
        ),
      ),
    );
  }
}