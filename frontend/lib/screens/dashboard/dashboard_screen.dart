import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Schedule the initial data load AFTER the first frame so that provider
    // notifications (e.g. notifyListeners inside loadCurrentUser / subscribe)
    // never run during the widget build phase. Otherwise Flutter throws
    // "setState() or markNeedsBuild() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _subscribeToData();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribeToData();
    }
  }

  void _subscribeToData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    context.read<IncomeProvider>().subscribe();
    context.read<ExpenseProvider>().subscribe();
    context.read<BudgetProvider>().subscribe();
    context.read<GoalProvider>().subscribe();
    context.read<UserProvider>().loadCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final incomeProvider = context.watch<IncomeProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final goalProvider = context.watch<GoalProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalIncome = incomeProvider.totalIncome;
    final totalExpense = expenseProvider.totalExpense;
    final balance = totalIncome - totalExpense;
    final budgetRemaining = budgetProvider.totalRemaining;
    final healthScore = _calculateHealthScore(totalIncome, totalExpense, goalProvider.totalSavings);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _subscribeToData(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, userProvider, isDark),
                const SizedBox(height: 20),
                _buildBalanceCard(context, balance, totalIncome, totalExpense, isDark),
                const SizedBox(height: 16),
                _buildQuickStats(context, totalIncome, totalExpense, budgetRemaining, healthScore, isDark),
                const SizedBox(height: 20),
                _buildSpendingChart(context, expenseProvider, isDark),
                const SizedBox(height: 20),
                _buildCategoryChart(context, expenseProvider, isDark),
                const SizedBox(height: 20),
                _buildRecentTransactions(context, expenseProvider, isDark),
                const SizedBox(height: 20),
                _buildGoalsSection(context, goalProvider, isDark),
                const SizedBox(height: 20),
                _buildAiInsights(context, totalIncome, totalExpense, healthScore, isDark),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProvider userProvider, bool isDark) {
    final now = DateTime.now();
    final greeting = _getGreeting();
    final userName = userProvider.user?.name ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
    final photoUrl = userProvider.user?.photoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, 👋',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : const Color(0xFF8E8EA0),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMMM d').format(now),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE8E8F0),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person, color: isDark ? Colors.white60 : const Color(0xFF8E8EA0))
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF2A2A3E)
                    : const Color(0xFFF0F0F5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance, double income, double expense, bool isDark) {
    return GlassCard(
      gradient: AppTheme.primaryGradient,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Balance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${balance >= 0 ? '●' : '○'} ${balance >= 0 ? 'Positive' : 'Negative'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedCounter(
            value: balance,
            prefix: '₹',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Income', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                        Text('₹${income.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expenses', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                        Text('₹${expense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, double income, double expense, double budgetRemaining, int healthScore, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: PremiumCard(
            title: 'Budget Left',
            value: '₹${budgetRemaining.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF00D9A6),
            subtitle: budgetRemaining > 0 ? 'On track' : 'Exceeded',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumCard(
            title: 'Health Score',
            value: '$healthScore',
            icon: Icons.favorite_outline,
            color: healthScore > 70 ? const Color(0xFF00D9A6) : const Color(0xFFFFB84D),
            subtitle: healthScore > 70 ? 'Good' : 'Needs work',
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingChart(BuildContext context, ExpenseProvider expenseProvider, bool isDark) {
    final monthlyExpense = expenseProvider.monthlyExpense;
    final weeklyExpense = expenseProvider.weeklyExpense;
    final todayExpense = expenseProvider.todayExpense;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending Overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'This Month',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(context, 'Today', '₹${todayExpense.toStringAsFixed(0)}', const Color(0xFFFF6584), isDark),
              _buildStatItem(context, 'This Week', '₹${weeklyExpense.toStringAsFixed(0)}', const Color(0xFFFFB84D), isDark),
              _buildStatItem(context, 'This Month', '₹${monthlyExpense.toStringAsFixed(0)}', const Color(0xFF6C63FF), isDark),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _buildBarChart(context, expenseProvider, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, ExpenseProvider expenseProvider, bool isDark) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    double maxDailyExpense = 10.0;
    for (var day in days) {
      final dayExpenses = expenseProvider.expenses.where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day);
      final total = dayExpenses.fold(0.0, (sum, e) => sum + e.amount);
      if (total > maxDailyExpense) {
        maxDailyExpense = total;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxDailyExpense * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dayNames.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(dayNames[index], style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: days.asMap().entries.map((entry) {
          final dayExpenses = expenseProvider.expenses.where((e) =>
              e.date.year == entry.value.year &&
              e.date.month == entry.value.month &&
              e.date.day == entry.value.day);
          final total = dayExpenses.fold(0.0, (sum, e) => sum + e.amount);
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: total > 0 ? total : 10,
                color: const Color(0xFF6C63FF),
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChart(BuildContext context, ExpenseProvider expenseProvider, bool isDark) {
    final breakdown = expenseProvider.categoryBreakdown;
    final total = expenseProvider.totalExpense;
    final colors = [
      const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF00D9A6),
      const Color(0xFFFFB84D), const Color(0xFF4DABF7), const Color(0xFFFF8A9E),
      const Color(0xFF845EF7), const Color(0xFF20C997),
    ];

    if (breakdown.isEmpty) {
      return GlassCard(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text('No expense data yet', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense Breakdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: breakdown.entries.toList().asMap().entries.map((entry) {
                        final percentage = total > 0 ? (entry.value.value / total) * 100 : 0;
                        return PieChartSectionData(
                          value: entry.value.value,
                          color: colors[entry.key % colors.length],
                          radius: 50,
                          title: '${percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: breakdown.entries.take(4).toList().asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: colors[entry.key % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.value.key,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, ExpenseProvider expenseProvider, bool isDark) {
    final recent = expenseProvider.expenses.take(5).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No transactions yet', style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            ...recent.map((expense) => _buildTransactionItem(context, expense, isDark)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, dynamic expense, bool isDark) {
    final categoryIcons = {
      'Food': Icons.restaurant,
      'Transport': Icons.directions_car,
      'Shopping': Icons.shopping_bag,
      'Bills': Icons.receipt_long,
      'Entertainment': Icons.movie,
      'Health': Icons.favorite,
      'Education': Icons.school,
      'Other': Icons.more_horiz,
    };
    final categoryColors = {
      'Food': const Color(0xFFFF6584),
      'Transport': const Color(0xFFFFB84D),
      'Shopping': const Color(0xFF6C63FF),
      'Bills': const Color(0xFF4DABF7),
      'Entertainment': const Color(0xFF845EF7),
      'Health': const Color(0xFF00D9A6),
      'Education': const Color(0xFF20C997),
      'Other': const Color(0xFF8E8EA0),
    };

    final icon = categoryIcons[expense.category] ?? Icons.receipt_long;
    final color = categoryColors[expense.category] ?? const Color(0xFF8E8EA0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description.isNotEmpty ? expense.description : expense.category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm a').format(expense.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '-₹${expense.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: const Color(0xFFFF4757),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(BuildContext context, GoalProvider goalProvider, bool isDark) {
    final goals = goalProvider.goals.take(3).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Savings Goals', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No goals set yet', style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            ...goals.map((goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
                      Text('${(goal.progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: const Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: goal.progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE8E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${goal.savedAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildAiInsights(BuildContext context, double income, double expense, int healthScore, bool isDark) {
    final savings = income - expense;
    String insight;
    IconData insightIcon;
    Color insightColor;

    if (savings < 0) {
      insight = 'Your expenses exceed your income. Consider reducing non-essential spending.';
      insightIcon = Icons.warning_amber_rounded;
      insightColor = const Color(0xFFFF4757);
    } else if (savings < income * 0.2) {
      insight = 'You\'re saving ${((savings / income) * 100).toStringAsFixed(0)}% of your income. Try to save at least 20%.';
      insightIcon = Icons.trending_up;
      insightColor = const Color(0xFFFFB84D);
    } else {
      insight = 'Great job! You\'re saving ${((savings / income) * 100).toStringAsFixed(0)}% of your income. Keep it up!';
      insightIcon = Icons.emoji_events;
      insightColor = const Color(0xFF00D9A6);
    }

    return GlassCard(
      gradient: isDark ? AppTheme.darkCardGradient : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: insightColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(insightIcon, color: insightColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Insight',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateHealthScore(double income, double expense, double savings) {
    if (income == 0) return 50;
    final savingsRatio = (income - expense) / income;
    if (savingsRatio >= 0.3) return 95;
    if (savingsRatio >= 0.2) return 85;
    if (savingsRatio >= 0.1) return 70;
    if (savingsRatio >= 0) return 55;
    return 40;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}