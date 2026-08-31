import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String paymentMethod;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final String? walletId;
  final String? walletName;

  const ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.description,
    required this.date,
    required this.createdAt,
    this.walletId,
    this.walletName,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ExpenseModel(
      id: documentId,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      walletId: map['walletId'],
      walletName: map['walletName'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (walletId != null) {
      map['walletId'] = walletId;
      map['walletName'] = walletName;
    }
    return map;
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? paymentMethod,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? walletId,
    String? walletName,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
    );
  }
}