import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../services/firebase/firebase_service.dart';

class GoalProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<GoalModel> _goals = [];
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription? _subscription;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalSavings =>
      _goals.fold(0, (total, goal) => total + goal.savedAmount);

  double get totalTargets =>
      _goals.fold(0, (total, goal) => total + goal.targetAmount);

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription?.cancel();
      _subscription = _firebaseService.goalsRef
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        _goals = snapshot.docs
            .map((doc) => GoalModel.fromMap(doc.data(), doc.id))
            .toList();
        _goals.sort((a, b) => a.targetDate.compareTo(b.targetDate));
        _error = null;
        notifyListeners();
      }, onError: (error) {
        debugPrint('GoalProvider subscription error: $error');
        _error = FirebaseService.getFriendlyError(error);
        notifyListeners();
      });
  }

  Future<bool> addGoal(GoalModel goal) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.addGoal(goal);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('GoalProvider.addGoal error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateGoal(GoalModel goal) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.updateGoal(goal);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('GoalProvider.updateGoal error: $e');
      notifyListeners();
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