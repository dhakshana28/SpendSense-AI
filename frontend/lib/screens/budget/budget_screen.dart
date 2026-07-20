import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/user_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = userProvider.user?.currency ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => budgetProvider.subscribe(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(context, budgetProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildSummaryCards(context, budgetProvider, currency, isDark),
              const SizedBox(height: 20),
              ...budgetProvider.budgets.map((budget) => _buildBudgetCard(context, budget, currency, isDark)),
              if (budgetProvider.budgets.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text('No budgets set. Create your first budget!', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context, budgetProvider, currency),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Budget'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BudgetProvider budgetProvider, String currency, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your spending limits',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BudgetProvider budgetProvider, String currency, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalBudget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Spent', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalRemaining.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context, BudgetModel budget, String currency, bool isDark) {
    final progress = (budget.spentAmount / budget.budgetAmount).clamp(0.0, 1.0);
    final remaining = budget.budgetAmount - budget.spentAmount;
    final isExceeded = remaining < 0;
    final progressColor = isExceeded
        ? const Color(0xFFFF4757)
        : progress > 0.8
            ? const Color(0xFFFFB84D)
            : const Color(0xFF00D9A6);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkCardGradient : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isExceeded ? const Color(0xFFFF4757).withValues(alpha: 0.3) : const Color(0xFF6C63FF).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.category,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExceeded ? 'Exceeded' : 'On Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Text(
                      '$currency${budget.budgetAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Spent', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Text(
                      '$currency${budget.spentAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Remaining', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  Text(
                    '$currency${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isExceeded ? const Color(0xFFFF4757) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isExceeded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4757), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: You have exceeded your budget!',
                      style: TextStyle(color: Color(0xFFFF4757), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddBudgetDialog(BuildContext context, BudgetProvider budgetProvider, String currency) async {
    final categoryController = TextEditingController();
    final budgetAmountController = TextEditingController();
    final spentAmountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Budget', style: Theme.of(context).textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g., Food, Transport'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Budget Amount ($currency)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: spentAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Spent Amount ($currency)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.isEmpty || budgetAmountController.text.isEmpty) return;
                final budget = BudgetModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  category: categoryController.text,
                  budgetAmount: double.parse(budgetAmountController.text),
                  spentAmount: double.parse(spentAmountController.text.isNotEmpty ? spentAmountController.text : '0'),
                  startDate: DateTime.now(),
                  endDate: DateTime.now().add(const Duration(days: 30)),
                );
                await budgetProvider.addBudget(budget);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}