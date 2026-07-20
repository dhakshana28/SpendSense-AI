import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../services/firebase/firebase_service.dart';

class GoalProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<GoalModel> _goals = [];
  final bool _isLoading = false;
  String? _error;
  StreamSubscription? _subscription;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalSavings =>
      _goals.fold(0, (total, goal) => total + goal.savedAmount);

  double get totalTargets =>
      _goals.fold(0, (total, goal) => total + goal.targetAmount);

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription = _firebaseService.goalsRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('targetDate', descending: false)
        .snapshots()
        .listen((snapshot) {
      _goals = snapshot.docs
          .map((doc) => GoalModel.fromMap(doc.data(), doc.id))
          .toList();
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('GoalProvider subscription error: $error');
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> addGoal(GoalModel goal) async {
    try {
      await _firebaseService.addGoal(goal);
    } catch (e) {
      debugPrint('GoalProvider.addGoal error: $e');
      rethrow;
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    try {
      await _firebaseService.updateGoal(goal);
    } catch (e) {
      debugPrint('GoalProvider.updateGoal error: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _firebaseService.deleteGoal(id);
    } catch (e) {
      debugPrint('GoalProvider.deleteGoal error: $e');
      rethrow;
    }
  }

  void clear() {
    _goals.clear();
    _subscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}