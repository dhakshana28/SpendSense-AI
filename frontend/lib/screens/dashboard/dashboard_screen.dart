import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/income_provider.dart';
import '../../app/constants/app_constants.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final incomeProvider = context.watch<IncomeProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final goalProvider = context.watch<GoalProvider>();

    final balance = incomeProvider.totalIncome - expenseProvider.totalExpense;
    final savings = balance > 0 ? balance : 0;
    final budgetUsed = incomeProvider.totalIncome == 0
        ? 0.0
        : (expenseProvider.totalExpense / incomeProvider.totalIncome) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendSense AI'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 500)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hello, Finance Explorer',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Here is your financial snapshot',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  title: 'Balance',
                  value:
                      '${AppConstants.currency}${balance.toStringAsFixed(0)}',
                  color: Colors.blue,
                ),
                _SummaryCard(
                  title: 'Income',
                  value:
                      '${AppConstants.currency}${incomeProvider.totalIncome.toStringAsFixed(0)}',
                  color: Colors.green,
                ),
                _SummaryCard(
                  title: 'Expenses',
                  value:
                      '${AppConstants.currency}${expenseProvider.totalExpense.toStringAsFixed(0)}',
                  color: Colors.orange,
                ),
                _SummaryCard(
                  title: 'Savings',
                  value:
                      '${AppConstants.currency}${savings.toStringAsFixed(0)}',
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Budget Utilization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('${budgetUsed.toStringAsFixed(0)}%'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (budgetUsed / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Financial Health Score: ${goalProvider.totalSavings > 0 ? 78 : 65}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      3,
                      (index) => ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text('Transaction #${index + 1}'),
                        subtitle: Text('Updated just now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: Card(
        color: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
