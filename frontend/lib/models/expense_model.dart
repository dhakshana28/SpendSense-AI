import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String paymentMethod;
  final String description;
  final String? receiptImage;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.description,
    this.receiptImage,
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ExpenseModel(
      id: documentId,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      description: map['description'] ?? '',
      receiptImage: map['receiptImage'],
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'description': description,
      'receiptImage': receiptImage,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? paymentMethod,
    String? description,
    String? receiptImage,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      receiptImage: receiptImage ?? this.receiptImage,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}