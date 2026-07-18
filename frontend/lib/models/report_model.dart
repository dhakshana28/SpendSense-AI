import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String userId;
  final DateTime createdAt;
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double budgetUsed;
  final double financialHealthScore;

  const ReportModel({
    required this.userId,
    required this.createdAt,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.budgetUsed,
    required this.financialHealthScore,
  });

  factory ReportModel.empty(String userId) {
    return ReportModel(
      userId: userId,
      createdAt: DateTime.now(),
      totalIncome: 0,
      totalExpense: 0,
      totalSavings: 0,
      budgetUsed: 0,
      financialHealthScore: 0,
    );
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      totalIncome: (map['totalIncome'] ?? 0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0).toDouble(),
      totalSavings: (map['totalSavings'] ?? 0).toDouble(),
      budgetUsed: (map['budgetUsed'] ?? 0).toDouble(),
      financialHealthScore: (map['financialHealthScore'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'totalSavings': totalSavings,
      'budgetUsed': budgetUsed,
      'financialHealthScore': financialHealthScore,
    };
  }
}
