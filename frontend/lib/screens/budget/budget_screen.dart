import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../app/constants/app_constants.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.budgets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No budgets created yet.')),
              ),
            )
          else
            ...provider.budgets.map(
              (budget) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            budget.category,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(budget.isExceeded ? 'Exceeded' : 'On Track'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (budget.spentAmount / budget.budgetAmount).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppConstants.currency}${budget.spentAmount.toStringAsFixed(0)} / ${AppConstants.currency}${budget.budgetAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<BudgetProvider>().addBudget(
            BudgetModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: 'demo-user',
              category: 'Food',
              budgetAmount: 5000,
              spentAmount: 3200,
              startDate: DateTime.now(),
              endDate: DateTime.now().add(const Duration(days: 30)),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Budget'),
      ),
    );
  }
}
