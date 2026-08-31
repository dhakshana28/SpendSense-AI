import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String source;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final String? walletId;
  final String? walletName;

  const IncomeModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.source,
    required this.description,
    required this.date,
    required this.createdAt,
    this.walletId,
    this.walletName,
  });

  factory IncomeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return IncomeModel(
      id: documentId,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      source: map['source'] ?? '',
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
      'source': source,
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

  IncomeModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? source,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? walletId,
    String? walletName,
  }) {
    return IncomeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      source: source ?? this.source,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
    );
  }
}