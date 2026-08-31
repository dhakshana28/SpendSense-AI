import '../../models/goal_model.dart';
import '../../models/expense_model.dart';
import '../../models/income_model.dart';

class GoalPlan {
  final String goalTitle;
  final double targetAmount;
  final double currentSaved;
  final double progress;
  final DateTime targetDate;
  final DateTime? predictedCompletionDate;
  final double requiredMonthly;
  final bool isOnTrack;
  final String suggestion;

  const GoalPlan({
    required this.goalTitle,
    required this.targetAmount,
    required this.currentSaved,
    required this.progress,
    required this.targetDate,
    this.predictedCompletionDate,
    required this.requiredMonthly,
    required this.isOnTrack,
    required this.suggestion,
  });
}

class GoalPlanner {
  static GoalPlan? analyze({
    required GoalModel goal,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
  }) {
    final monthsUntilTarget = goal.targetDate.difference(DateTime.now()).inDays / 30.0;
    if (monthsUntilTarget <= 0) return null;

    final remainingAmount = goal.targetAmount - goal.savedAmount;
    final requiredMonthly = remainingAmount / (monthsUntilTarget > 0 ? monthsUntilTarget : 1);

    // Calculate average monthly savings
    final now = DateTime.now();
    final monthlyIncomes = incomes.where((i) =>
        i.date.month == now.month && i.date.year == now.year).toList();
    final monthlyExpenses = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year).toList();
    final monthlyIncome = monthlyIncomes.fold(0.0, (sum, i) => sum + i.amount);
    final monthlyExpense = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final monthlySavings = monthlyIncome - monthlyExpense;

    // Estimate completion date based on current savings rate
    DateTime? predictedDate;
    bool isOnTrack = false;
    String suggestion;

    if (monthlySavings > 0) {
      final monthsNeeded = remainingAmount / monthlySavings;
      final predicted = DateTime.now().add(Duration(days: (monthsNeeded * 30).round()));
      predictedDate = predicted;
      isOnTrack = predicted.isBefore(goal.targetDate) || predicted.isAtSameMomentAs(goal.targetDate);

      if (isOnTrack) {
        suggestion = 'You\'re on track! Keep saving ₹${monthlySavings.toStringAsFixed(0)} per month. '
            'Estimated completion: ${_formatDate(predicted)}';
      } else if (requiredMonthly <= monthlySavings * 1.5) {
        suggestion = 'You\'re close! Try saving ₹${requiredMonthly.toStringAsFixed(0)} per month '
            '(currently saving ₹${monthlySavings.toStringAsFixed(0)}).';
      } else {
        suggestion = 'Consider increasing your monthly savings to ₹${requiredMonthly.toStringAsFixed(0)} '
            '(currently ₹${monthlySavings.toStringAsFixed(0)}). '
            'Can you reduce discretionary spending?';
      }
    } else {
      suggestion = 'You need to start saving. Try cutting expenses to allocate '
          '₹${requiredMonthly.toStringAsFixed(0)} per month for this goal.';
    }

    return GoalPlan(
      goalTitle: goal.title,
      targetAmount: goal.targetAmount,
      currentSaved: goal.savedAmount,
      progress: goal.progress,
      targetDate: goal.targetDate,
      predictedCompletionDate: predictedDate,
      requiredMonthly: double.parse(requiredMonthly.toStringAsFixed(2)),
      isOnTrack: isOnTrack,
      suggestion: suggestion,
    );
  }

  static String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  static Map<String, double> getSuggestedGoalAmounts() {
    return {
      'Emergency Fund': 50000,
      'Vacation': 25000,
      'Bike': 100000,
      'Laptop': 60000,
      'Education': 75000,
      'House': 500000,
    };
  }
}