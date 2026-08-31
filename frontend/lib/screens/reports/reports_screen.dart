import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'Monthly';

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final incomeProvider = context.watch<IncomeProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = userProvider.user?.currency ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            expenseProvider.subscribe();
            incomeProvider.subscribe();
          },
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(context, currency, isDark),
              const SizedBox(height: 20),
              _buildPeriodSelector(context, isDark),
              const SizedBox(height: 20),
              _buildSummaryCards(context, expenseProvider, incomeProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildIncomeVsExpenseChart(context, expenseProvider, incomeProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildCategoryBreakdown(context, expenseProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildMonthlyTrend(context, expenseProvider, incomeProvider, currency, isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String currency, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Financial insights and analytics',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Weekly', 'Monthly', 'Yearly'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (isDark ? const Color(0xFF6C63FF) : const Color(0xFF6C63FF)) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF8E8EA0)),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ExpenseProvider expenseProvider, IncomeProvider incomeProvider, String currency, bool isDark) {
    final totalIncome = incomeProvider.totalIncome;
    final totalExpense = expenseProvider.totalExpense;
    final savings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0;

    return Row(
      children: [
        Expanded(
          child: _ReportCard(
            title: 'Income',
            value: '$currency${totalIncome.toStringAsFixed(0)}',
            icon: Icons.arrow_upward,
            color: const Color(0xFF00D9A6),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReportCard(
            title: 'Expenses',
            value: '$currency${totalExpense.toStringAsFixed(0)}',
            icon: Icons.arrow_downward,
            color: const Color(0xFFFF6584),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReportCard(
            title: 'Savings Rate',
            value: '${savingsRate.toStringAsFixed(0)}%',
            icon: Icons.savings,
            color: const Color(0xFF4DABF7),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeVsExpenseChart(BuildContext context, ExpenseProvider expenseProvider, IncomeProvider incomeProvider, String currency, bool isDark) {
    final totalIncome = incomeProvider.totalIncome;
    final totalExpense = expenseProvider.totalExpense;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: max(totalIncome, totalExpense) > 0 ? max(totalIncome, totalExpense) * 1.2 : 1000,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Income', 'Expenses'];
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[value.toInt()], style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: incomeProvider.totalIncome,
                        color: const Color(0xFF00D9A6),
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: expenseProvider.totalExpense,
                        color: const Color(0xFFFF6584),
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, ExpenseProvider expenseProvider, String currency, bool isDark) {
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
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: isDark ? Colors.white60 : const Color(0xFF8E8EA0)),
                const SizedBox(height: 16),
                Text('No expense data yet', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense by Category', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: breakdown.entries.take(5).toList().asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: colors[entry.key % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value.key,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$currency${entry.value.value.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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

  Widget _buildMonthlyTrend(BuildContext context, ExpenseProvider expenseProvider, IncomeProvider incomeProvider, String currency, bool isDark) {
    // Build live monthly trend data for the last 6 months.
    const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final labels = <String>[];
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    double maxValue = 0;

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      labels.add(monthLabels[monthDate.month - 1]);

      final monthIncome = incomeProvider.incomeList
          .where((x) => x.date.year == monthDate.year && x.date.month == monthDate.month)
          .fold(0.0, (sum, x) => sum + x.amount);
      final monthExpense = expenseProvider.expenseList
          .where((x) => x.date.year == monthDate.year && x.date.month == monthDate.month)
          .fold(0.0, (sum, x) => sum + x.amount);

      if (monthIncome > maxValue) maxValue = monthIncome;
      if (monthExpense > maxValue) maxValue = monthExpense;

      incomeSpots.add(FlSpot(i.toDouble(), monthIncome));
      expenseSpots.add(FlSpot(i.toDouble(), monthExpense));
    }

    final double chartMaxY = maxValue > 0 ? maxValue * 1.2 : 1000.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                maxY: chartMaxY,
                lineTouchData: LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[value.toInt()], style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    color: const Color(0xFF00D9A6),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF00D9A6).withValues(alpha: 0.1)),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    color: const Color(0xFFFF6584),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFFFF6584).withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double max(double a, double b) => a > b ? a : b;
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.9), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}