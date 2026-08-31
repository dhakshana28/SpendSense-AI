import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/goal_model.dart';
import '../../models/budget_model.dart';

class HealthScoreResult {
  final int score;
  final String label;
  final String description;
  final List<String> reasons;

  const HealthScoreResult({
    required this.score,
    required this.label,
    required this.description,
    required this.reasons,
  });
}

class FinancialHealthScoreCalculator {
  static HealthScoreResult calculate({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<GoalModel> goals,
    required List<BudgetModel> budgets,
  }) {
    final reasons = <String>[];
    int score = 50; // Start at neutral

    final totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amount);
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // 1. Income stability (+0 to +15)
    if (totalIncome > 0 && incomes.length >= 3) {
      final incomeAmounts = incomes.map((i) => i.amount).toList();
      final avgIncome = incomeAmounts.reduce((a, b) => a + b) / incomeAmounts.length;
      final variance = incomeAmounts.map((a) => (a - avgIncome).abs()).reduce((a, b) => a + b) / incomeAmounts.length;
      if (variance / (avgIncome > 0 ? avgIncome : 1) < 0.3) {
        score += 15;
        reasons.add('✓ Stable income source');
      } else {
        score += 5;
        reasons.add('~ Variable income detected');
      }
    } else {
      reasons.add('~ Limited income data');
    }

    // 2. Savings ratio (0 to +25)
    if (totalIncome > 0) {
      final savingsRatio = (totalIncome - totalExpense) / totalIncome;
      if (savingsRatio >= 0.3) {
        score += 25;
        reasons.add('✓ Excellent savings rate (${(savingsRatio * 100).toStringAsFixed(0)}%)');
      } else if (savingsRatio >= 0.2) {
        score += 20;
        reasons.add('✓ Good savings rate (${(savingsRatio * 100).toStringAsFixed(0)}%)');
      } else if (savingsRatio >= 0.1) {
        score += 10;
        reasons.add('~ Moderate savings rate (${(savingsRatio * 100).toStringAsFixed(0)}%)');
      } else if (savingsRatio >= 0) {
        score += 5;
        reasons.add('~ Low savings rate (${(savingsRatio * 100).toStringAsFixed(0)}%)');
      } else {
        score -= 10;
        reasons.add('✗ Spending exceeds income');
      }
    }

    // 3. Budget discipline (0 to +20)
    if (budgets.isNotEmpty) {
      int onBudget = 0;
      for (final budget in budgets) {
        if (!budget.isExceeded) onBudget++;
      }
      final disciplineRatio = onBudget / budgets.length;
      score += (disciplineRatio * 20).round();
      if (disciplineRatio > 0.7) {
        reasons.add('✓ Good budget discipline');
      } else if (disciplineRatio > 0.3) {
        reasons.add('~ Some budgets exceeded');
      } else {
        reasons.add('✗ Most budgets exceeded');
      }
    } else {
      reasons.add('~ No budgets set');
    }

    // 4. Overspending check (-10 to 0)
    if (totalIncome > 0 && totalExpense > totalIncome * 1.2) {
      score -= 10;
      reasons.add('✗ Significant overspending detected');
    }

    // 5. Goal completion (0 to +20)
    if (goals.isNotEmpty) {
      final avgProgress = goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length;
      score += (avgProgress * 20).round();
      if (avgProgress > 0.7) {
        reasons.add('✓ Great goal progress');
      } else if (avgProgress > 0.3) {
        reasons.add('~ Goals in progress');
      } else {
        reasons.add('~ Goals need attention');
      }
    } else {
      reasons.add('~ No financial goals set');
    }

    // Clamp score
    score = score.clamp(0, 100);

    // Determine label
    String label;
    String description;
    if (score >= AppConstants.excellentScore) {
      label = 'Excellent';
      description = 'Your financial health is excellent! Keep up the great work.';
    } else if (score >= AppConstants.goodScore) {
      label = 'Good';
      description = 'Your financial health is good. Small improvements can make it excellent.';
    } else if (score >= AppConstants.averageScore) {
      label = 'Average';
      description = 'Your financial health is average. Focus on increasing savings and reducing unnecessary expenses.';
    } else if (score >= AppConstants.poorScore) {
      label = 'Needs Improvement';
      description = 'Your financial health needs attention. Create a budget and track your expenses regularly.';
    } else {
      label = 'Poor';
      description = 'Your financial health requires immediate attention. Consider financial counseling.';
    }

    return HealthScoreResult(
      score: score,
      label: label,
      description: description,
      reasons: reasons,
    );
  }
}

class AppConstants {
  static const int excellentScore = 90;
  static const int goodScore = 75;
  static const int averageScore = 60;
  static const int poorScore = 40;
}