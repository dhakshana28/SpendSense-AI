import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense_model.dart';
import '../services/firebase/firebase_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<ExpenseModel> _expenses = [];
  final bool _isLoading = false;
  String? _error;
  StreamSubscription? _subscription;

  List<ExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalExpense =>
      _expenses.fold(0, (total, item) => total + item.amount);

  double get monthlyExpense {
    final now = DateTime.now();
    final monthly = _expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year);
    return monthly.fold(0, (total, item) => total + item.amount);
  }

  double get weeklyExpense {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekly = _expenses.where((e) =>
        e.date.isAfter(weekAgo) && e.date.isBefore(now.add(const Duration(days: 1))));
    return weekly.fold(0, (total, item) => total + item.amount);
  }

  double get todayExpense {
    final now = DateTime.now();
    final today = _expenses.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
    return today.fold(0, (total, item) => total + item.amount);
  }

  Map<String, double> get categoryBreakdown {
    final breakdown = <String, double>{};
    for (final expense in _expenses) {
      breakdown[expense.category] =
          (breakdown[expense.category] ?? 0) + expense.amount;
    }
    return breakdown;
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription = _firebaseService.expensesRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('ExpenseProvider subscription error: $error');
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await _firebaseService.addExpense(expense);
    } catch (e) {
      debugPrint('ExpenseProvider.addExpense error: $e');
      rethrow;
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _firebaseService.updateExpense(expense);
    } catch (e) {
      debugPrint('ExpenseProvider.updateExpense error: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _firebaseService.deleteExpense(id);
    } catch (e) {
      debugPrint('ExpenseProvider.deleteExpense error: $e');
      rethrow;
    }
  }

  void clear() {
    _expenses.clear();
    _subscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}