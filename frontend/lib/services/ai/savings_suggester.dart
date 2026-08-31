import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';

class SavingsSuggestion {
  final String title;
  final String description;
  final double potentialSavings;
  final String category;
  final SuggestionPriority priority;

  const SavingsSuggestion({
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.category,
    required this.priority,
  });
}

enum SuggestionPriority { high, medium, low }

class SavingsSuggester {
  static List<SavingsSuggestion> generate({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
  }) {
    final suggestions = <SavingsSuggestion>[];
    if (expenses.isEmpty) return suggestions;

    final now = DateTime.now();
    final thisMonth = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year).toList();
    final totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amount);
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // 1. Category overspending analysis
    final categoryTotals = <String, double>{};
    for (final expense in thisMonth) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCategories.take(3)) {
      final category = entry.key;
      final amount = entry.value;
      final total = totalExpense > 0 ? totalExpense : 1;
      final percentage = (amount / total) * 100;

      if (percentage > 30) {
        final suggestedReduction = amount * 0.15;
        suggestions.add(SavingsSuggestion(
          title: 'Reduce $category spending',
          description:
              'You spent ${percentage.toStringAsFixed(0)}% of your expenses on $category. '
              'Consider reducing by 15% to save ₹${suggestedReduction.toStringAsFixed(0)}.',
          potentialSavings: suggestedReduction,
          category: category,
          priority: SuggestionPriority.high,
        ));
      }
    }

    // 2. Budget exceeded check
    for (final budget in budgets) {
      final spent = expenses
          .where((e) =>
              e.date.isAfter(budget.startDate) &&
              e.date.isBefore(budget.endDate))
          .fold(0.0, (sum, e) => sum + e.amount);
      if (spent > budget.budgetAmount) {
        suggestions.add(SavingsSuggestion(
          title: 'Budget exceeded for ${budget.category}',
          description:
              'Your ${budget.category} budget of ₹${budget.budgetAmount.toStringAsFixed(0)} '
              'was exceeded by ₹${(spent - budget.budgetAmount).toStringAsFixed(0)}. '
              'Try to stay within limits next month.',
          potentialSavings: spent - budget.budgetAmount,
          category: budget.category,
          priority: SuggestionPriority.high,
        ));
      }
    }

    // 3. Travel expense increase detection
    final lastMonthExpenses = expenses.where((e) =>
        e.date.month == now.month - 1 && e.date.year == now.year).toList();
    final travelThisMonth = thisMonth
        .where((e) => e.category == 'Travel')
        .fold(0.0, (sum, e) => sum + e.amount);
    final travelLastMonth = lastMonthExpenses
        .where((e) => e.category == 'Travel')
        .fold(0.0, (sum, e) => sum + e.amount);
    if (travelThisMonth > travelLastMonth && travelLastMonth > 0) {
      final increase = travelThisMonth - travelLastMonth;
      suggestions.add(SavingsSuggestion(
        title: 'Travel expenses increased',
        description:
            'Your travel spending increased by ₹${increase.toStringAsFixed(0)} '
            'compared to last month. Consider planning trips better.',
        potentialSavings: increase * 0.3,
        category: 'Travel',
        priority: SuggestionPriority.medium,
      ));
    }

    // 4. General savings opportunity
    if (totalIncome > 0) {
      final savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
      if (savingsRate < 20) {
        final targetSavings = totalIncome * 0.2;
        final currentSavings = totalIncome - totalExpense;
        final additionalSavings = targetSavings - currentSavings;
        if (additionalSavings > 0) {
          suggestions.add(SavingsSuggestion(
            title: 'Increase your savings rate',
            description:
                'You\'re saving ${savingsRate.toStringAsFixed(0)}% of income. '
                'Try to save at least 20% (₹${additionalSavings.toStringAsFixed(0)} more per month).',
            potentialSavings: additionalSavings,
            category: 'General',
            priority: SuggestionPriority.medium,
          ));
        }
      } else {
        suggestions.add(SavingsSuggestion(
          title: 'Great savings habit!',
          description:
              'You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income. '
              'You may save ₹${(totalIncome - totalExpense).toStringAsFixed(0)} this month!',
          potentialSavings: totalIncome - totalExpense,
          category: 'General',
          priority: SuggestionPriority.low,
        ));
      }
    }

    // 5. Entertainment subscription check
    final entertainmentTotal = thisMonth
        .where((e) => e.category == 'Entertainment')
        .fold(0.0, (sum, e) => sum + e.amount);
    if (entertainmentTotal > 1000) {
      suggestions.add(SavingsSuggestion(
        title: 'Review entertainment subscriptions',
        description:
            'You spent ₹${entertainmentTotal.toStringAsFixed(0)} on entertainment. '
            'Review unused subscriptions to save money.',
        potentialSavings: entertainmentTotal * 0.2,
        category: 'Entertainment',
        priority: SuggestionPriority.medium,
      ));
    }

    suggestions.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return suggestions;
  }
}