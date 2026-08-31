import '../../models/expense_model.dart';

class SpendingPrediction {
  final double nextWeek;
  final double nextMonth;
  final double confidence;
  final Map<String, double> categoryPredictions;
  final List<double> historicalWeekly;
  final List<double> historicalMonthly;

  const SpendingPrediction({
    required this.nextWeek,
    required this.nextMonth,
    required this.confidence,
    required this.categoryPredictions,
    required this.historicalWeekly,
    required this.historicalMonthly,
  });
}

class SpendingPredictor {
  /// Predicts future spending using moving average and linear regression
  static SpendingPrediction predict(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      return SpendingPrediction(
        nextWeek: 0,
        nextMonth: 0,
        confidence: 0,
        categoryPredictions: {},
        historicalWeekly: [],
        historicalMonthly: [],
      );
    }

    final sorted = List<ExpenseModel>.from(expenses)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Group by week
    final weeklyTotals = <double>[];
    final now = DateTime.now();
    for (int w = 0; w < 8; w++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + w * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final total = sorted
          .where((e) => e.date.isAfter(weekStart) && e.date.isBefore(weekEnd))
          .fold(0.0, (sum, e) => sum + e.amount);
      weeklyTotals.add(total);
    }

    // Group by month
    final monthlyTotals = <double>[];
    for (int m = 0; m < 6; m++) {
      final monthStart = DateTime(now.year, now.month - m, 1);
      final monthEnd = DateTime(now.year, now.month - m + 1, 1);
      final total = sorted
          .where((e) => e.date.isAfter(monthStart) && e.date.isBefore(monthEnd))
          .fold(0.0, (sum, e) => sum + e.amount);
      monthlyTotals.add(total);
    }

    // Moving average for weekly prediction
    final recentWeekly = weeklyTotals.take(4).toList();
    final weeklyMovingAvg = recentWeekly.isEmpty
        ? 0.0
        : recentWeekly.reduce((a, b) => a + b) / recentWeekly.length;

    // Linear regression for monthly prediction
    final monthlyPrediction = _linearRegression(monthlyTotals);
    final monthlyMovingAvg = monthlyTotals.isEmpty
        ? 0.0
        : monthlyTotals.reduce((a, b) => a + b) / monthlyTotals.length;

    final predictedWeekly = (weeklyMovingAvg * 0.7) + (monthlyMovingAvg / 4 * 0.3);
    final predictedMonthly = (monthlyPrediction * 0.6) + (monthlyMovingAvg * 0.4);

    // Category predictions
    final categoryPredictions = <String, double>{};
    for (final expense in sorted) {
      categoryPredictions[expense.category] =
          (categoryPredictions[expense.category] ?? 0) + expense.amount;
    }
    // Average monthly per category
    final monthCount = monthlyTotals.isNotEmpty ? monthlyTotals.length : 1;
    categoryPredictions.updateAll((key, value) => value / monthCount);

    // Confidence score based on data volume
    final dataPoints = sorted.length;
    final confidence = (dataPoints / 50).clamp(0.0, 1.0);

    return SpendingPrediction(
      nextWeek: double.parse(predictedWeekly.toStringAsFixed(2)),
      nextMonth: double.parse(predictedMonthly.toStringAsFixed(2)),
      confidence: double.parse(confidence.toStringAsFixed(2)),
      categoryPredictions: categoryPredictions,
      historicalWeekly: weeklyTotals.reversed.toList(),
      historicalMonthly: monthlyTotals.reversed.toList(),
    );
  }

  static double _linearRegression(List<double> values) {
    if (values.length < 2) {
      return values.isEmpty ? 0 : values.last;
    }

    final n = values.length;
    final indices = List.generate(n, (i) => i.toDouble());
    final sumX = indices.reduce((a, b) => a + b);
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = _zipWith(indices, values, (a, b) => a * b).reduce((a, b) => a + b);
    final sumX2 = indices.map((x) => x * x).reduce((a, b) => a + b);

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Predict next value (n)
    final prediction = slope * n + intercept;
    return prediction > 0 ? prediction : 0;
  }

  static List<double> _zipWith(
      List<double> a, List<double> b, double Function(double, double) f) {
    final result = <double>[];
    for (int i = 0; i < a.length && i < b.length; i++) {
      result.add(f(a[i], b[i]));
    }
    return result;
  }
}