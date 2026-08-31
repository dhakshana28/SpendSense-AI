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
    this.age,
    this.occupation,
    this.persona,
    this.financialGoals = const [],
    this.createdAt,
    this.updatedAt,
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
  final int? age;
  final String? occupation;
  final String? persona;
  final List<String> financialGoals;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
        age: (map['age'] as num?)?.toInt(),
        occupation: map['occupation'] as String?,
        persona: map['persona'] as String?,
        financialGoals: (map['financialGoals'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
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
        'age': age,
        'occupation': occupation,
        'persona': persona,
        'financialGoals': financialGoals,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(updatedAt!),
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? currency,
    double? monthlyIncome,
    double? monthlyBudget,
    int? age,
    String? occupation,
    String? persona,
    List<String>? financialGoals,
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
        age: age ?? this.age,
        occupation: occupation ?? this.occupation,
        persona: persona ?? this.persona,
        financialGoals: financialGoals ?? this.financialGoals,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

