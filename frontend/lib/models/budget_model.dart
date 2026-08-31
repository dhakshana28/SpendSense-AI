import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final DateTime startDate;
  final DateTime endDate;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.startDate,
    required this.endDate,
  });

  double get remainingAmount => budgetAmount - spentAmount;

  bool get isExceeded => spentAmount > budgetAmount;

  factory BudgetModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return BudgetModel(
      id: documentId,
      userId: map['userId'] ?? '',
      category: map['category'] ?? '',
      budgetAmount: (map['budgetAmount'] ?? 0).toDouble(),
      spentAmount: (map['spentAmount'] ?? 0).toDouble(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'category': category,
        'budgetAmount': budgetAmount,
        'spentAmount': spentAmount,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      };

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? budgetAmount,
    double? spentAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}