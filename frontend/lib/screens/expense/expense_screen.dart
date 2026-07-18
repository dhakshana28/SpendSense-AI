import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../app/constants/app_constants.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Expenses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppConstants.currency}${provider.totalExpense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (provider.expenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No expense records yet.')),
              ),
            )
          else
            ...provider.expenses.map(
              (expense) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.shopping_bag_outlined),
                  ),
                  title: Text(expense.category),
                  subtitle: Text(
                    '${expense.paymentMethod} • ${expense.description}',
                  ),
                  trailing: Text(
                    '${AppConstants.currency}${expense.amount.toStringAsFixed(0)}',
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<ExpenseProvider>().addExpense(
            ExpenseModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: 'demo-user',
              amount: 1200,
              category: 'Food',
              paymentMethod: 'Card',
              description: 'Groceries',
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
