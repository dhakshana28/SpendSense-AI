import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/glass_card.dart';

/// Displays budget alerts globally across the application.
class GlobalAlertsBanner extends StatelessWidget {
  const GlobalAlertsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build budget alerts from current data.
    final alerts = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final budget in budgetProvider.budgets) {
      if (budget.isExceeded) {
        alerts.add({
          'title': '${budget.category} budget exceeded',
          'message': 'Exceeded by ₹${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(0)}',
          'color': const Color(0xFFFF4757),
          'icon': Icons.warning_rounded,
        });
      } else if (budget.budgetAmount > 0) {
        final progress = budget.spentAmount / budget.budgetAmount;
        if (progress >= 0.9) {
          alerts.add({
            'title': '${budget.category} budget at ${(progress * 100).toStringAsFixed(0)}%',
            'message': '₹${budget.remainingAmount.toStringAsFixed(0)} remaining',
            'color': const Color(0xFFFFB84D),
            'icon': Icons.warning_amber_rounded,
          });
        } else if (progress >= 0.8) {
          alerts.add({
            'title': '${budget.category} budget at ${(progress * 100).toStringAsFixed(0)}%',
            'message': '₹${budget.remainingAmount.toStringAsFixed(0)} remaining',
            'color': const Color(0xFF6C63FF),
            'icon': Icons.info_outline,
          });
        }
      }
    }

    // Large expense alert for today.
    final todayExpenses = expenseProvider.expenses.where((e) =>
      e.date.year == now.year && e.date.month == now.month && e.date.day == now.day
    ).toList();
    if (todayExpenses.isNotEmpty) {
      final todayTotal = todayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
      if (todayTotal > 5000) {
        alerts.add({
          'title': 'High spending today',
          'message': '₹${todayTotal.toStringAsFixed(0)} spent today',
          'color': const Color(0xFFFF6584),
          'icon': Icons.trending_up,
        });
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.take(3).map((alert) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (alert['color'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(alert['icon'] as IconData, color: alert['color'] as Color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['title'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        alert['message'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}