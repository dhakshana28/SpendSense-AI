import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.currency = '₹',
    this.monthlyIncome = 0,
    this.monthlyBudget = 0,
    this.savingsGoal = 0,
    this.financialHealthScore = 0,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String currency;
  final double monthlyIncome;
  final double monthlyBudget;
  final double savingsGoal;
  final int financialHealthScore;
  final DateTime? createdAt;

  factory UserModel.createDefault(User user) => UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String? ?? '',
        name: map['name'] as String? ?? map['fullName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        photoUrl: map['photoUrl'] as String? ?? map['profileImage'] as String?,
        currency: map['currency'] as String? ?? '₹',
        monthlyIncome: (map['monthlyIncome'] as num? ?? 0).toDouble(),
        monthlyBudget: (map['monthlyBudget'] as num? ?? 0).toDouble(),
        savingsGoal: (map['savingsGoal'] as num? ?? 0).toDouble(),
        financialHealthScore: map['financialHealthScore'] as int? ?? 0,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'monthlyIncome': monthlyIncome,
        'monthlyBudget': monthlyBudget,
        'savingsGoal': savingsGoal,
        'financialHealthScore': financialHealthScore,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? currency,
    double? monthlyIncome,
    double? monthlyBudget,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        currency: currency ?? this.currency,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        savingsGoal: savingsGoal,
        financialHealthScore: financialHealthScore,
        createdAt: createdAt,
      );
}
