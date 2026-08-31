import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/chat_message_model.dart';

class ChatHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatRef =>
      _firestore.collection('ai_chat_history');

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> saveMessage({
    required String question,
    required String response,
    Map<String, dynamic>? contextSnapshot,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final message = ChatMessageModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
        userId: userId,
        question: question,
        response: response,
        timestamp: DateTime.now(),
        contextSnapshot: contextSnapshot,
      );
      await _chatRef.doc(message.id).set(message.toMap());
      debugPrint('ChatHistoryService: Message saved');
    } catch (e) {
      debugPrint('ChatHistoryService: Save failed: $e');
    }
  }

  Stream<List<ChatMessageModel>> getChatHistory() {
    final userId = _userId;
    if (userId == null) return Stream.value([]);

    return _chatRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatRef.doc(messageId).delete();
      debugPrint('ChatHistoryService: Message deleted');
    } catch (e) {
      debugPrint('ChatHistoryService: Delete failed: $e');
    }
  }

  Future<void> clearAllHistory() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final snapshot = await _chatRef
          .where('userId', isEqualTo: userId)
          .get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('ChatHistoryService: All messages cleared');
    } catch (e) {
      debugPrint('ChatHistoryService: Clear failed: $e');
    }
  }
}