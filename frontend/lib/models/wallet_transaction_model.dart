import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  final String id;
  final String userId;
  final String walletId;
  final String walletName;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String description;
  final String? referenceId; // income or expense document ID
  final DateTime date;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.walletName,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    this.referenceId,
    required this.date,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WalletTransactionModel(
      id: documentId,
      userId: map['userId'] ?? '',
      walletId: map['walletId'] ?? '',
      walletName: map['walletName'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      referenceId: map['referenceId'],
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'walletId': walletId,
      'walletName': walletName,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (referenceId != null) {
      map['referenceId'] = referenceId;
    }
    return map;
  }

  WalletTransactionModel copyWith({
    String? id,
    String? userId,
    String? walletId,
    String? walletName,
    String? type,
    double? amount,
    String? category,
    String? description,
    String? referenceId,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}