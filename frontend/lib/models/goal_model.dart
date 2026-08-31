import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String userId;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime targetDate;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
  });

  double get progress =>
      targetAmount == 0 ? 0 : savedAmount / targetAmount;

  factory GoalModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return GoalModel(
      id: documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      savedAmount: (map['savedAmount'] ?? 0).toDouble(),
      targetDate: (map['targetDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'targetDate': Timestamp.fromDate(targetDate),
      };

  GoalModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
    );
  }
}