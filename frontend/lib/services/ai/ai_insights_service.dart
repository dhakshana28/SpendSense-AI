import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';

class AIInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final String emoji;
  final double? value;
  final DateTime timestamp;
  final String period;

  const AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.emoji,
    this.value,
    required this.timestamp,
    required this.period,
  });
}

enum InsightType { positive, negative, neutral, warning }

class AIInsightsService {
  static List<AIInsight> generateDailyInsights({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final insights = <AIInsight>[];
    final now = DateTime.now();
    final today = expenses.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day).toList();
    final yesterday = expenses.where((e) {
      final y = now.subtract(const Duration(days: 1));
      return e.date.year == y.year && e.date.month == y.month && e.date.day == y.day;
    }).toList();

    final todayTotal = today.fold(0.0, (s, e) => s + e.amount);
    final yesterdayTotal = yesterday.fold(0.0, (s, e) => s + e.amount);

    // Daily spending comparison
    if (yesterdayTotal > 0) {
      final diff = ((todayTotal - yesterdayTotal) / yesterdayTotal) * 100;
      if (diff < -10) {
        insights.add(AIInsight(
          id: 'daily_spend_down_${now.millisecondsSinceEpoch}',
          title: 'Spending decreased today',
          description: 'You spent ${diff.abs().toStringAsFixed(0)}% less than yesterday. Great job!',
          type: InsightType.positive,
          emoji: '📉',
          value: diff,
          timestamp: now,
          period: 'daily',
        ));
      } else if (diff > 20) {
        insights.add(AIInsight(
          id: 'daily_spend_up_${now.millisecondsSinceEpoch}',
          title: 'Spending increased today',
          description: 'You spent ${diff.toStringAsFixed(0)}% more than yesterday.',
          type: InsightType.warning,
          emoji: '📈',
          value: diff,
          timestamp: now,
          period: 'daily',
        ));
      }
    }

    // Large expense detection
    if (today.isNotEmpty) {
      final maxExpense = today.reduce((a, b) => a.amount > b.amount ? a : b);
      if (maxExpense.amount > 5000) {
        insights.add(AIInsight(
          id: 'large_expense_${maxExpense.id}',
          title: 'Large expense detected',
          description: '₹${maxExpense.amount.toStringAsFixed(0)} spent on ${maxExpense.category}${maxExpense.description.isNotEmpty ? ' — ${maxExpense.description}' : ''}',
          type: InsightType.neutral,
          emoji: '🔔',
          value: maxExpense.amount,
          timestamp: now,
          period: 'daily',
        ));
      }
    }

    return insights;
  }

  static List<AIInsight> generateWeeklyInsights({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final insights = <AIInsight>[];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));

    final thisWeek = expenses.where((e) =>
        e.date.isAfter(weekStart) && e.date.isBefore(now.add(const Duration(days: 1)))).toList();
    final lastWeek = expenses.where((e) =>
        e.date.isAfter(lastWeekStart) && e.date.isBefore(weekStart)).toList();

    final thisWeekTotal = thisWeek.fold(0.0, (s, e) => s + e.amount);
    final lastWeekTotal = lastWeek.fold(0.0, (s, e) => s + e.amount);

    // Weekly comparison
    if (lastWeekTotal > 0) {
      final diff = ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100;
      if (diff < -10) {
        insights.add(AIInsight(
          id: 'weekly_down_${now.millisecondsSinceEpoch}',
          title: 'Spending decreased this week',
          description: 'You spent ${diff.abs().toStringAsFixed(0)}% less than last week (₹${(lastWeekTotal - thisWeekTotal).toStringAsFixed(0)} saved).',
          type: InsightType.positive,
          emoji: '🎯',
          value: diff,
          timestamp: now,
          period: 'weekly',
        ));
      } else if (diff > 15) {
        insights.add(AIInsight(
          id: 'weekly_up_${now.millisecondsSinceEpoch}',
          title: 'Spending increased this week',
          description: 'You spent ${diff.toStringAsFixed(0)}% more than last week (₹${(thisWeekTotal - lastWeekTotal).toStringAsFixed(0)} extra).',
          type: InsightType.warning,
          emoji: '⚠️',
          value: diff,
          timestamp: now,
          period: 'weekly',
        ));
      }
    }

    // Category trend
    final categoryThisWeek = <String, double>{};
    for (final e in thisWeek) {
      categoryThisWeek[e.category] = (categoryThisWeek[e.category] ?? 0) + e.amount;
    }
    final categoryLastWeek = <String, double>{};
    for (final e in lastWeek) {
      categoryLastWeek[e.category] = (categoryLastWeek[e.category] ?? 0) + e.amount;
    }

    for (final entry in categoryThisWeek.entries) {
      final lastAmount = categoryLastWeek[entry.key] ?? 0;
      if (lastAmount > 0) {
        final change = ((entry.value - lastAmount) / lastAmount) * 100;
        if (change.abs() > 20) {
          final isDown = change < 0;
          insights.add(AIInsight(
            id: 'cat_${entry.key}_${now.millisecondsSinceEpoch}',
            title: '${entry.key} ${isDown ? 'decreased' : 'increased'}',
            description: '${entry.key} spending ${isDown ? 'decreased' : 'increased'} by ${change.abs().toStringAsFixed(0)}% this week.',
            type: isDown ? InsightType.positive : InsightType.warning,
            emoji: isDown ? '✅' : '📊',
            value: change,
            timestamp: now,
            period: 'weekly',
          ));
        }
      }
    }

    return insights;
  }

  static List<AIInsight> generateMonthlyInsights({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final insights = <AIInsight>[];
    final now = DateTime.now();
    final thisMonth = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year).toList();
    final lastMonth = expenses.where((e) =>
        e.date.month == now.month - 1 && e.date.year == now.year).toList();
    final thisMonthIncome = incomes.where((i) =>
        i.date.month == now.month && i.date.year == now.year).toList();

    final monthlyExpense = thisMonth.fold(0.0, (s, e) => s + e.amount);
    final lastMonthExpense = lastMonth.fold(0.0, (s, e) => s + e.amount);
    final monthlyIncome = thisMonthIncome.fold(0.0, (s, i) => s + i.amount);

    // Month-over-month
    if (lastMonthExpense > 0) {
      final diff = ((monthlyExpense - lastMonthExpense) / lastMonthExpense) * 100;
      if (diff.abs() > 10) {
        insights.add(AIInsight(
          id: 'monthly_${now.millisecondsSinceEpoch}',
          title: diff < 0 ? 'Monthly spending decreased' : 'Monthly spending increased',
          description: diff < 0
              ? 'You spent ${diff.abs().toStringAsFixed(0)}% less this month. You saved ₹${(lastMonthExpense - monthlyExpense).toStringAsFixed(0)}!'
              : 'You spent ${diff.toStringAsFixed(0)}% more this month compared to last.',
          type: diff < 0 ? InsightType.positive : InsightType.warning,
          emoji: diff < 0 ? '💰' : '📊',
          value: diff,
          timestamp: now,
          period: 'monthly',
        ));
      }
    }

    // Savings rate
    if (monthlyIncome > 0) {
      final savingsRate = ((monthlyIncome - monthlyExpense) / monthlyIncome) * 100;
      final savedAmount = monthlyIncome - monthlyExpense;
      if (savingsRate >= 20) {
        insights.add(AIInsight(
          id: 'savings_${now.millisecondsSinceEpoch}',
          title: 'Great savings this month!',
          description: 'You saved ₹${savedAmount.toStringAsFixed(0)} (${savingsRate.toStringAsFixed(0)}% of income). Keep it up!',
          type: InsightType.positive,
          emoji: '🎉',
          value: savedAmount,
          timestamp: now,
          period: 'monthly',
        ));
      } else if (savingsRate < 0) {
        insights.add(AIInsight(
          id: 'overspend_${now.millisecondsSinceEpoch}',
          title: 'Expenses exceeded income',
          description: 'You spent ₹${savedAmount.abs().toStringAsFixed(0)} more than you earned this month.',
          type: InsightType.negative,
          emoji: '🚨',
          value: savedAmount,
          timestamp: now,
          period: 'monthly',
        ));
      }
    }

    // Budget check
    for (final budget in budgets) {
      if (budget.isExceeded) {
        insights.add(AIInsight(
          id: 'budget_exceed_${budget.id}',
          title: '${budget.category} budget exceeded',
          description: 'Your ${budget.category} budget of ₹${budget.budgetAmount.toStringAsFixed(0)} has been exceeded by ₹${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(0)}.',
          type: InsightType.warning,
          emoji: '🚫',
          value: budget.spentAmount - budget.budgetAmount,
          timestamp: now,
          period: 'monthly',
        ));
      }
    }

    // Goal progress
    for (final goal in goals) {
      if (goal.progress >= 0.9 && goal.progress < 1.0) {
        insights.add(AIInsight(
          id: 'goal_near_${goal.id}',
          title: 'Almost there!',
          description: 'Your "${goal.title}" goal is ${(goal.progress * 100).toStringAsFixed(0)}% complete. Just ₹${(goal.targetAmount - goal.savedAmount).toStringAsFixed(0)} to go!',
          type: InsightType.positive,
          emoji: '🏆',
          value: goal.progress,
          timestamp: now,
          period: 'monthly',
        ));
      } else if (goal.progress >= 1.0) {
        insights.add(AIInsight(
          id: 'goal_done_${goal.id}',
          title: 'Goal achieved! 🎉',
          description: 'Congratulations! You\'ve completed your "${goal.title}" goal!',
          type: InsightType.positive,
          emoji: '🏆',
          value: 1.0,
          timestamp: now,
          period: 'monthly',
        ));
      }
    }

    // Sort by type priority
    insights.sort((a, b) => a.type.index.compareTo(b.type.index));
    return insights;
  }

  static List<AIInsight> generateAll({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
  }) {
    final all = <AIInsight>[];
    all.addAll(generateDailyInsights(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
    ));
    all.addAll(generateWeeklyInsights(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
    ));
    all.addAll(generateMonthlyInsights(
      incomes: incomes, expenses: expenses, budgets: budgets, goals: goals,
    ));
    return all;
  }
}