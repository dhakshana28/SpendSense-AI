import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../app/constants/app_constants.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.goals.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No savings goals yet.')),
              ),
            )
          else
            ...provider.goals.map(
              (goal) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: goal.progress.clamp(0.0, 1.0),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppConstants.currency}${goal.savedAmount.toStringAsFixed(0)} / ${AppConstants.currency}${goal.targetAmount.toStringAsFixed(0)}',
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
          context.read<GoalProvider>().addGoal(
            GoalModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: 'demo-user',
              title: 'Emergency Fund',
              targetAmount: 100000,
              savedAmount: 25000,
              targetDate: DateTime.now().add(const Duration(days: 180)),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
    );
  }
}
