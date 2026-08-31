import '../models/budget_model.dart';
import '../models/expense_model.dart';
import '../models/goal_model.dart';
import '../models/income_model.dart';

class AIAlert {
  final String id;
  final String title;
  final String message;
  final AlertType type;
  final String emoji;
  final DateTime timestamp;
  final bool isRead;

  const AIAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.emoji,
    required this.timestamp,
    this.isRead = false,
  });
}

enum AlertType { info, warning, success, danger }

class AlertService {
  static List<AIAlert> generateAlerts({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final alerts = <AIAlert>[];
    final now = DateTime.now();

    // Budget exceeded alerts
    for (final budget in budgets) {
      if (budget.isExceeded) {
        alerts.add(AIAlert(
          id: 'budget_exceed_${budget.id}',
          title: 'Budget Exceeded',
          message: 'Your ${budget.category} budget of Rs. ${budget.budgetAmount.toStringAsFixed(0)} has been exceeded by Rs. ${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(0)}.',
          type: AlertType.danger,
          emoji: '🚫',
          timestamp: now,
        ));
      } else if (budget.remainingAmount < budget.budgetAmount * 0.2) {
        alerts.add(AIAlert(
          id: 'budget_warning_${budget.id}',
          title: 'Budget Almost Exceeded',
          message: 'You have only Rs. ${budget.remainingAmount.toStringAsFixed(0)} left in your ${budget.category} budget (80% used).',
          type: AlertType.warning,
          emoji: '⚠️',
          timestamp: now,
        ));
      }
    }

    // Goal completion alerts
    for (final goal in goals) {
      if (goal.progress >= 1.0) {
        alerts.add(AIAlert(
          id: 'goal_complete_${goal.id}',
          title: 'Goal Achieved! 🎉',
          message: 'Congratulations! You have completed your "${goal.title}" goal!',
          type: AlertType.success,
          emoji: '🏆',
          timestamp: now,
        ));
      } else if (goal.progress >= 0.9) {
        final remaining = goal.targetAmount - goal.savedAmount;
        alerts.add(AIAlert(
          id: 'goal_near_${goal.id}',
          title: 'Almost There!',
          message: 'Your "${goal.title}" goal is ${(goal.progress * 100).toStringAsFixed(0)}% complete. Only Rs. ${remaining.toStringAsFixed(0)} to go!',
          type: AlertType.info,
          emoji: '🎯',
          timestamp: now,
        ));
      }
    }

    // Large expense detection
    final today = expenses.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day).toList();

    if (today.isNotEmpty) {
      final maxExpense = today.reduce((a, b) => a.amount > b.amount ? a : b);
      if (maxExpense.amount > 10000) {
        alerts.add(AIAlert(
          id: 'large_expense_${maxExpense.id}',
          title: 'Large Expense Detected',
          message: 'Rs. ${maxExpense.amount.toStringAsFixed(0)} spent on ${maxExpense.category}${maxExpense.description.isNotEmpty ? ' - ${maxExpense.description}' : ''}.',
          type: AlertType.warning,
          emoji: '🔔',
          timestamp: now,
        ));
      }
    }

    // Subscription reminders
    final subscriptionKeywords = ['netflix', 'spotify', 'amazon prime', 'hotstar', 'youtube premium', 'gym'];
    for (final keyword in subscriptionKeywords) {
      final hasSubscription = expenses.any((e) => e.description.toLowerCase().contains(keyword));
      if (hasSubscription) {
        final lastSubscription = expenses.firstWhere((e) => e.description.toLowerCase().contains(keyword));
        final daysSince = now.difference(lastSubscription.date).inDays;
        if (daysSince >= 25 && daysSince <= 35) {
          alerts.add(AIAlert(
            id: 'subscription_$keyword',
            title: 'Subscription Due',
            message: 'Your $keyword subscription may be due soon. Last payment: Rs. ${lastSubscription.amount.toStringAsFixed(0)} on ${lastSubscription.date.toIso8601String().split('T')[0]}.',
            type: AlertType.info,
            emoji: '💳',
            timestamp: now,
          ));
        }
      }
    }

    // Savings increase alert
    final lastMonthIncome = incomes.where((i) =>
        i.date.month == now.month - 1 && i.date.year == now.year).toList();
    final thisMonthIncome = incomes.where((i) =>
        i.date.month == now.month && i.date.year == now.year).toList();

    if (lastMonthIncome.isNotEmpty && thisMonthIncome.isNotEmpty) {
      final lastMonthTotal = lastMonthIncome.fold(0.0, (s, i) => s + i.amount);
      final thisMonthTotal = thisMonthIncome.fold(0.0, (s, i) => s + i.amount);
      if (thisMonthTotal > lastMonthTotal * 1.1) {
        alerts.add(AIAlert(
          id: 'income_increased',
          title: 'Income Increased! 💰',
          message: 'Your income this month is ${((thisMonthTotal / lastMonthTotal - 1) * 100).toStringAsFixed(0)}% higher than last month.',
          type: AlertType.success,
          emoji: '📈',
          timestamp: now,
        ));
      }
    }

    // Sort by type priority
    alerts.sort((a, b) => a.type.index.compareTo(b.type.index));
    return alerts;
  }
}