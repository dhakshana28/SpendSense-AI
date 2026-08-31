import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/theme/app_theme.dart';
import '../../providers/savings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/glass_card.dart';

class SavingsAnalyticsScreen extends StatefulWidget {
  const SavingsAnalyticsScreen({super.key});

  @override
  State<SavingsAnalyticsScreen> createState() => _SavingsAnalyticsScreenState();
}

class _SavingsAnalyticsScreenState extends State<SavingsAnalyticsScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  DateTime? _lastBuildTime;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    debugPrint('[SAVINGS] Screen opened');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribe();
    });
  }

  void _subscribe() {
    final sw = Stopwatch()..start();
    debugPrint('[SAVINGS] Provider initialization started');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    context.read<SavingsProvider>().subscribe();
    context.read<WalletProvider>().subscribe();
    sw.stop();
    debugPrint('[SAVINGS] Provider initialization completed: ${sw.elapsedMilliseconds}ms');
  }

  @override
  Widget build(BuildContext context) {
    final buildSw = Stopwatch()..start();
    final savingsProvider = context.watch<SavingsProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentSavings = savingsProvider.currentSavings;
    final monthlySavings = savingsProvider.monthlySavings;
    final savingsPercentage = savingsProvider.savingsPercentage;
    final savingsGrowth = savingsProvider.savingsGrowth;
    final totalIncome = savingsProvider.totalIncome;
    final totalExpenses = savingsProvider.totalExpenses;
    final monthlyIncome = savingsProvider.monthlyIncome;
    final monthlyExpense = savingsProvider.monthlyExpense;
    final savingsTrend = savingsProvider.monthlySavingsTrend;

    buildSw.stop();
    if (_lastBuildTime != null) {
      debugPrint('[SAVINGS] UI rebuild completed in ${buildSw.elapsedMilliseconds}ms');
    }
    _lastBuildTime = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _subscribe(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Analytics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your savings performance',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),

                // Current Savings Card
                GlassCard(
                  gradient: AppTheme.primaryGradient,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Current Savings',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${currentSavings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSavingsBadge(context, 'Monthly', '₹${monthlySavings.toStringAsFixed(0)}', isDark),
                            const SizedBox(width: 16),
                            _buildSavingsBadge(context, 'Percentage', '${savingsPercentage.toStringAsFixed(1)}%', isDark),
                            const SizedBox(width: 16),
                            _buildSavingsBadge(context, 'Growth', '${savingsGrowth.toStringAsFixed(1)}%', isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Income vs Expenses
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context, 'Total Income', '₹${totalIncome.toStringAsFixed(0)}',
                        Icons.arrow_downward, const Color(0xFF00D9A6), isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context, 'Total Expenses', '₹${totalExpenses.toStringAsFixed(0)}',
                        Icons.arrow_upward, const Color(0xFFFF6584), isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context, 'Monthly Income', '₹${monthlyIncome.toStringAsFixed(0)}',
                        Icons.trending_down, const Color(0xFF4DABF7), isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context, 'Monthly Expenses', '₹${monthlyExpense.toStringAsFixed(0)}',
                        Icons.trending_up, const Color(0xFFFFB84D), isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Savings Trend Chart
                Text(
                  'Savings Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 220,
                      child: savingsTrend.isEmpty
                          ? Center(
                              child: Text('No data yet', style: Theme.of(context).textTheme.bodyMedium),
                            )
                          : LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: 1,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final entries = savingsTrend.entries.toList();
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < entries.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              entries[idx].key,
                                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black45),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                minY: 0,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: savingsTrend.entries.toList().asMap().entries.map((entry) {
                                      return FlSpot(entry.key.toDouble(), entry.value.value < 0 ? 0 : entry.value.value);
                                    }).toList(),
                                    isCurved: true,
                                    color: const Color(0xFF6C63FF),
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(milliseconds: 500),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Savings Goal Progress
                Text(
                  'Savings Goal Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overall Progress', style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              '${(savingsProvider.savingsGoalProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: savingsProvider.savingsGoalProgress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE8E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${currentSavings.toStringAsFixed(0)} saved of ₹${totalIncome.toStringAsFixed(0)} total income',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Wallet-wise Savings
                Text(
                  'Wallet-wise Savings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (walletProvider.wallets.isEmpty)
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 48,
                              color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 12),
                            Text('No wallets created yet',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white38 : Colors.black38)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...walletProvider.wallets.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_wallet,
                                color: Color(0xFF6C63FF), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(w.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500)),
                            ),
                            Text(
                              '₹${w.currentBalance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSavingsBadge(BuildContext context, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon, Color color, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}