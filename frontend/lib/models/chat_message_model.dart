import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String userId;
  final String question;
  final String response;
  final DateTime timestamp;
  final Map<String, dynamic>? contextSnapshot;

  const ChatMessageModel({
    required this.id,
    required this.userId,
    required this.question,
    required this.response,
    required this.timestamp,
    this.contextSnapshot,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessageModel(
      id: docId,
      userId: map['userId'] ?? '',
      question: map['question'] ?? '',
      response: map['response'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contextSnapshot: map['contextSnapshot'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'question': question,
        'response': response,
        'timestamp': Timestamp.fromDate(timestamp),
        if (contextSnapshot != null) 'contextSnapshot': contextSnapshot,
      };
}