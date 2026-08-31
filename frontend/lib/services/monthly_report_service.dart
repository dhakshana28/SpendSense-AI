import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';

class MonthlyReportData {
  final int month;
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double savings;
  final Map<String, double> categoryBreakdown;
  final List<ExpenseModel> transactions;
  final String? healthScore;
  final String? summary;

  const MonthlyReportData({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.savings,
    required this.categoryBreakdown,
    required this.transactions,
    this.healthScore,
    this.summary,
  });
}

class MonthlyReportService {
  static MonthlyReportData generateReport({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    int? month,
    int? year,
  }) {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final monthIncomes = incomes.where((i) => i.date.month == targetMonth && i.date.year == targetYear).toList();
    final monthExpenses = expenses.where((e) => e.date.month == targetMonth && e.date.year == targetYear).toList();

    final totalIncome = monthIncomes.fold(0.0, (s, i) => s + i.amount);
    final totalExpense = monthExpenses.fold(0.0, (s, e) => s + e.amount);
    final savings = totalIncome - totalExpense;

    final categoryBreakdown = <String, double>{};
    for (final e in monthExpenses) {
      categoryBreakdown[e.category] = (categoryBreakdown[e.category] ?? 0) + e.amount;
    }

    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return MonthlyReportData(
      month: targetMonth,
      year: targetYear,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savings: savings,
      categoryBreakdown: categoryBreakdown,
      transactions: monthExpenses,
      healthScore: null,
      summary: '${monthNames[targetMonth - 1]} $targetYear Report',
    );
  }

  static Future<File> generatePDF(MonthlyReportData report) async {
    final pdf = pw.Document();
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Financial Report - ${monthNames[report.month - 1]} ${report.year}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Total Income: Rs. ${report.totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('Total Expenses: Rs. ${report.totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('Net Savings: Rs. ${report.savings.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text('Category Breakdown:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...report.categoryBreakdown.entries.map((e) => pw.Text('${e.key}: Rs. ${e.value.toStringAsFixed(2)}')),
              pw.SizedBox(height: 20),
              pw.Text('Transactions:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...report.transactions.take(50).map((t) {
                return pw.Text('${t.date.toIso8601String().split('T')[0]} - ${t.category} - Rs. ${t.amount.toStringAsFixed(2)}');
              }),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/report_${report.month}_${report.year}.pdf')
      ..writeAsBytesSync(await pdf.save());
  }

  static Future<void> shareReport(MonthlyReportData report) async {
    // PDF generation works; sharing can be integrated via UI layer later.
  }
}