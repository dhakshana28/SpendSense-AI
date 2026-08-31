import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/savings_provider.dart';
import '../../widgets/glass_card.dart';
import 'wallet_list_screen.dart';
import 'wallet_form_screen.dart';

class WalletDashboardScreen extends StatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribe();
    });
  }

  void _subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    context.read<WalletProvider>().subscribe();
    context.read<SavingsProvider>().subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final savingsProvider = context.watch<SavingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalBalance = walletProvider.totalWalletBalance;
    final totalSavings = savingsProvider.currentSavings;
    final todayIncome = walletProvider.todayIncome;
    final todayExpense = walletProvider.todayExpense;
    final recentTransactions = walletProvider.recentTransactions;
    final walletDistribution = walletProvider.walletDistribution;

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
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet Dashboard',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Real-time overview',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletFormScreen()),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Wallet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Balance & Savings Cards
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        gradient: AppTheme.primaryGradient,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Wallet Balance',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '₹${totalBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D9A6), Color(0xFF00B894)],
                        ),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Total Savings',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '₹${totalSavings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Today's Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context, 'Today Income', '₹${todayIncome.toStringAsFixed(0)}',
                        Icons.arrow_downward, const Color(0xFF00D9A6), isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context, 'Today Expenses', '₹${todayExpense.toStringAsFixed(0)}',
                        Icons.arrow_upward, const Color(0xFFFF6584), isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Wallet Distribution Chart
                if (walletDistribution.isNotEmpty) ...[
                  Text(
                    'Wallet Distribution',
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
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: walletDistribution.entries.toList().asMap().entries.map((entry) {
                              final colors = [
                                const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF00D9A6),
                                const Color(0xFFFFB84D), const Color(0xFF4DABF7), const Color(0xFF845EF7),
                                const Color(0xFF20C997), const Color(0xFFFF8A9E),
                              ];
                              return PieChartSectionData(
                                value: entry.value.value,
                                color: colors[entry.key % colors.length],
                                radius: 50,
                                title: '${entry.value.value.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                          ),
                          duration: const Duration(milliseconds: 500),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: walletDistribution.entries.toList().asMap().entries.map((entry) {
                      final colors = [
                        const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF00D9A6),
                        const Color(0xFFFFB84D), const Color(0xFF4DABF7), const Color(0xFF845EF7),
                        const Color(0xFF20C997), const Color(0xFFFF8A9E),
                      ];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: colors[entry.key % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value.key} (${entry.value.value.toStringAsFixed(0)}%)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Recent Transactions
                Text(
                  'Recent Wallet Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (recentTransactions.isEmpty)
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48,
                              color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 12),
                            Text('No transactions yet',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white38 : Colors.black38)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...recentTransactions.take(5).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (t.type == 'income'
                                        ? const Color(0xFF00D9A6)
                                        : const Color(0xFFFF6584))
                                    .withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                t.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                                color: t.type == 'income' ? const Color(0xFF00D9A6) : const Color(0xFFFF6584),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.description.isNotEmpty ? t.description : t.category,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${t.walletName} • ${t.category}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${t.type == 'income' ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: t.type == 'income' ? const Color(0xFF00D9A6) : const Color(0xFFFF6584),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                const SizedBox(height: 20),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context, 'View Wallets', Icons.account_balance_wallet,
                        const Color(0xFF6C63FF), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WalletListScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context, 'Add Wallet', Icons.add_circle_outline,
                        const Color(0xFF00D9A6), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WalletFormScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, bool isDark) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GlassCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}