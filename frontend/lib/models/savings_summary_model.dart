import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsSummaryModel {
  final String id;
  final String userId;
  final double currentSavings;
  final double monthlySavings;
  final double yearlySavings;
  final double savingsPercentage;
  final double savingsGrowth;
  final double totalIncome;
  final double totalExpenses;
  final DateTime lastUpdated;
  final DateTime createdAt;

  const SavingsSummaryModel({
    required this.id,
    required this.userId,
    required this.currentSavings,
    required this.monthlySavings,
    required this.yearlySavings,
    required this.savingsPercentage,
    required this.savingsGrowth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.lastUpdated,
    required this.createdAt,
  });

  factory SavingsSummaryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SavingsSummaryModel(
      id: documentId,
      userId: map['userId'] ?? '',
      currentSavings: (map['currentSavings'] ?? 0).toDouble(),
      monthlySavings: (map['monthlySavings'] ?? 0).toDouble(),
      yearlySavings: (map['yearlySavings'] ?? 0).toDouble(),
      savingsPercentage: (map['savingsPercentage'] ?? 0).toDouble(),
      savingsGrowth: (map['savingsGrowth'] ?? 0).toDouble(),
      totalIncome: (map['totalIncome'] ?? 0).toDouble(),
      totalExpenses: (map['totalExpenses'] ?? 0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'currentSavings': currentSavings,
      'monthlySavings': monthlySavings,
      'yearlySavings': yearlySavings,
      'savingsPercentage': savingsPercentage,
      'savingsGrowth': savingsGrowth,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SavingsSummaryModel copyWith({
    String? id,
    String? userId,
    double? currentSavings,
    double? monthlySavings,
    double? yearlySavings,
    double? savingsPercentage,
    double? savingsGrowth,
    double? totalIncome,
    double? totalExpenses,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return SavingsSummaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentSavings: currentSavings ?? this.currentSavings,
      monthlySavings: monthlySavings ?? this.monthlySavings,
      yearlySavings: yearlySavings ?? this.yearlySavings,
      savingsPercentage: savingsPercentage ?? this.savingsPercentage,
      savingsGrowth: savingsGrowth ?? this.savingsGrowth,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}