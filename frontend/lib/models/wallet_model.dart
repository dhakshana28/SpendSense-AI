import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final double initialBalance;
  final double currentBalance;
  final String description;
  final DateTime createdDate;
  final DateTime lastUpdated;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    required this.initialBalance,
    required this.currentBalance,
    required this.description,
    required this.createdDate,
    required this.lastUpdated,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WalletModel(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'account_balance_wallet',
      color: map['color'] ?? '#6C63FF',
      initialBalance: (map['initialBalance'] ?? 0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'description': description,
      'createdDate': Timestamp.fromDate(createdDate),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  WalletModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    String? color,
    double? initialBalance,
    double? currentBalance,
    String? description,
    DateTime? createdDate,
    DateTime? lastUpdated,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}