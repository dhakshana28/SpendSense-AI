import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/income_model.dart';
import '../../providers/income_provider.dart';
import '../../app/constants/app_constants.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncomeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
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
                    'Total Income',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppConstants.currency}${provider.totalIncome.toStringAsFixed(0)}',
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
          if (provider.incomeList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No income records yet.')),
              ),
            )
          else
            ...provider.incomeList.map(
              (income) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.account_balance_wallet),
                  ),
                  title: Text(income.category),
                  subtitle: Text('${income.source} • ${income.description}'),
                  trailing: Text(
                    '${AppConstants.currency}${income.amount.toStringAsFixed(0)}',
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<IncomeProvider>().addIncome(
            IncomeModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: 'demo-user',
              amount: 5000,
              category: 'Salary',
              source: 'Monthly Pay',
              description: 'Salary deposit',
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
      ),
    );
  }
}
