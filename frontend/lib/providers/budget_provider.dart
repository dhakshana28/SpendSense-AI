import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../services/firebase/firebase_service.dart';

class BudgetProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<BudgetModel> _budgets = [];
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription? _subscription;

  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalBudget =>
      _budgets.fold(0, (total, item) => total + item.budgetAmount);

  double get totalSpent =>
      _budgets.fold(0, (total, item) => total + item.spentAmount);

  double get totalRemaining =>
      _budgets.fold(0, (total, item) => total + item.remainingAmount);

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription?.cancel();
      _subscription = _firebaseService.budgetsRef
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        _budgets = snapshot.docs
            .map((doc) => BudgetModel.fromMap(doc.data(), doc.id))
            .toList();
        _budgets.sort((a, b) => b.startDate.compareTo(a.startDate));
        _error = null;
        notifyListeners();
      }, onError: (error) {
        debugPrint('BudgetProvider subscription error: $error');
        _error = FirebaseService.getFriendlyError(error);
        notifyListeners();
      });
  }

  BudgetModel? getBudget(String category) {
    try {
      return _budgets.firstWhere((item) => item.category == category);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addBudget(BudgetModel budget) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.addBudget(budget);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('BudgetProvider.addBudget error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateBudget(BudgetModel budget) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.updateBudget(budget);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('BudgetProvider.updateBudget error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await _firebaseService.deleteBudget(id);
    } catch (e) {
      debugPrint('BudgetProvider.deleteBudget error: $e');
      rethrow;
    }
  }

  void clear() {
    _budgets.clear();
    _subscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}