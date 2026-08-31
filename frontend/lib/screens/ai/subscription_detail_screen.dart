import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_provider.dart';
import '../../providers/expense_provider.dart';
import '../../services/ai/subscription_detector.dart';
import '../../widgets/glass_card.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  const SubscriptionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIProvider>();
    final subscriptions = ai.subscriptions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMonthly = SubscriptionDetector.totalMonthlyCost(subscriptions);
    final totalYearly = SubscriptionDetector.totalAnnualCost(subscriptions);
    final activeCount = subscriptions.where((s) => s.isActive).length;
    final unusedCount = subscriptions.where((s) => s.isUnused).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Detector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final expenseProvider = context.read<ExpenseProvider>();
              ai.detectSubscriptions(expenseProvider.expenses);
            },
            tooltip: 'Refresh Subscriptions',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final expenseProvider = context.read<ExpenseProvider>();
          ai.detectSubscriptions(expenseProvider.expenses);
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(context, subscriptions, totalMonthly, totalYearly, activeCount, unusedCount),
              const SizedBox(height: 20),
              if (subscriptions.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ...subscriptions.map((sub) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSubscriptionCard(context, sub, isDark),
                )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<DetectedSubscription> subscriptions,
      double totalMonthly, double totalYearly, int activeCount, int unusedCount) {
    return GlassCard(
      gradient: const LinearGradient(colors: [Color(0xFFFF6584), Color(0xFFFF8FA3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.subscriptions, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$activeCount Active Subscriptions', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('₹${totalMonthly.toStringAsFixed(0)} / month', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSummaryStat(context, 'Yearly Cost', '₹${totalYearly.toStringAsFixed(0)}')),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryStat(context, 'Unused', '$unusedCount', isWarning: unusedCount > 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(BuildContext context, String label, String value, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFB84D).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 16),
            Text('No subscriptions detected yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(height: 8),
            Text('Add recurring expenses to see them here', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, DetectedSubscription sub, bool isDark) {
    final nextRenewal = sub.lastDetected.add(const Duration(days: 30));
    final daysUntilRenewal = nextRenewal.difference(DateTime.now()).inDays;

    return GlassCard(
      margin: EdgeInsets.zero,
      onTap: () => _showSubscriptionDetails(context, sub),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sub.isActive ? const Color(0xFF00D9A6).withValues(alpha: 0.1) : const Color(0xFFFF6584).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.subscriptions, color: sub.isActive ? const Color(0xFF00D9A6) : const Color(0xFFFF6584), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${sub.category} • ${sub.isActive ? 'Active' : 'Inactive'}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF6584).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('₹${sub.monthlyCost.toStringAsFixed(0)}/mo', style: const TextStyle(color: Color(0xFFFF6584), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailChip(context, 'Monthly', '₹${sub.monthlyCost.toStringAsFixed(0)}', isDark)),
                const SizedBox(width: 8),
                Expanded(child: _buildDetailChip(context, 'Yearly', '₹${(sub.monthlyCost * 12).toStringAsFixed(0)}', isDark)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDetailChip(context, 'Last Transaction', _formatDate(sub.lastDetected), isDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailChip(
                    context,
                    'Next Renewal',
                    daysUntilRenewal > 0 ? 'In $daysUntilRenewal days' : 'Overdue',
                    isDark,
                    isWarning: daysUntilRenewal <= 0,
                  ),
                ),
              ],
            ),
            if (sub.isUnused && sub.cancellationSuggestion != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFB84D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB84D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(sub.cancellationSuggestion!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB84D))),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(BuildContext context, String label, String value, bool isDark, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFB84D).withValues(alpha: 0.08) : isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isWarning ? const Color(0xFFFFB84D) : null)),
        ],
      ),
    );
  }

  void _showSubscriptionDetails(BuildContext context, DetectedSubscription sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(sub.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(sub.category, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              _buildDetailRow(context, 'Monthly Cost', '₹${sub.monthlyCost.toStringAsFixed(2)}'),
              _buildDetailRow(context, 'Yearly Cost', '₹${(sub.monthlyCost * 12).toStringAsFixed(2)}'),
              _buildDetailRow(context, 'Status', sub.isActive ? 'Active' : 'Inactive'),
              _buildDetailRow(context, 'Last Transaction', _formatDate(sub.lastDetected)),
              _buildDetailRow(context, 'Next Expected Renewal', _formatDate(sub.lastDetected.add(const Duration(days: 30)))),
              _buildDetailRow(context, 'Matched Transactions', '${sub.matchedExpenses.length}'),
              if (sub.isUnused) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFB84D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB84D)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(sub.cancellationSuggestion ?? 'Consider cancelling to save money.', style: const TextStyle(color: Color(0xFFFFB84D))),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}


