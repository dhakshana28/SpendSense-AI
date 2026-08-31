import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/firebase/firebase_service.dart';
import '../services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final _uuid = const Uuid();
  
  List<ExpenseModel> _expenseList = [];
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription? _subscription;

  List<ExpenseModel> get expenseList => _expenseList;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalExpense =>
      _expenseList.fold(0.0, (value, item) => value + item.amount);

  double get monthlyExpense {
    final now = DateTime.now();
    return _expenseList
        .where((item) =>
            item.date.month == now.month && item.date.year == now.year)
        .fold(0.0, (value, item) => value + item.amount);
  }

  List<ExpenseModel> get expenses => _expenseList;

  double get todayExpense {
    final now = DateTime.now();
    return _expenseList
        .where((item) =>
            item.date.year == now.year &&
            item.date.month == now.month &&
            item.date.day == now.day)
        .fold(0.0, (value, item) => value + item.amount);
  }

  double get weeklyExpense {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _expenseList
        .where((item) => item.date.isAfter(weekAgo))
        .fold(0.0, (value, item) => value + item.amount);
  }

  Map<String, double> get categoryBreakdown {
    final breakdown = <String, double>{};
    for (final expense in _expenseList) {
      breakdown[expense.category] =
          (breakdown[expense.category] ?? 0) + expense.amount;
    }
    return breakdown;
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription?.cancel();
    _subscription = _firebaseService.expensesRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _expenseList = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('ExpenseProvider subscription error: $error');
      _error = FirebaseService.getFriendlyError(error);
      notifyListeners();
    });
  }

  Future<bool> addExpense(ExpenseModel expense) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.addExpense(expense);

      // Update wallet balance if linked
      if (expense.walletId != null) {
        final walletRef = _firebaseService.walletsRef.doc(expense.walletId);
        await _firebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(walletRef);
          if (snapshot.exists) {
            final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
            transaction.update(walletRef, {
              'currentBalance': currentBalance - expense.amount,
              'lastUpdated': Timestamp.now(),
            });
          }
        });

        // Add wallet transaction record
        final wt = WalletTransactionModel(
          id: _uuid.v4(),
          userId: expense.userId,
          walletId: expense.walletId!,
          walletName: expense.walletName ?? '',
          type: 'expense',
          amount: expense.amount,
          category: expense.category,
          description: expense.description,
          referenceId: expense.id,
          date: expense.date,
          createdAt: DateTime.now(),
        );
        await _firebaseService.addWalletTransaction(wt);
      }

      _isSaving = false;
      notifyListeners();

      // Trigger notifications
      // Large expense detection
      if (expense.amount > 10000) {
        await NotificationService.showLargeExpenseAlert(
          amount: expense.amount,
          category: expense.category,
          description: expense.description,
        );
      }

      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('ExpenseProvider.addExpense error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateExpense(ExpenseModel expense) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final oldExpense = _expenseList.where((e) => e.id == expense.id).firstOrNull;
      
      await _firebaseService.updateExpense(expense);

      if (oldExpense != null) {
        if (oldExpense.walletId != expense.walletId) {
          // Revert old wallet
          if (oldExpense.walletId != null) {
            final oldWalletRef = _firebaseService.walletsRef.doc(oldExpense.walletId);
            await _firebaseService.firestore.runTransaction((transaction) async {
              final snapshot = await transaction.get(oldWalletRef);
              if (snapshot.exists) {
                final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
                transaction.update(oldWalletRef, {
                  'currentBalance': currentBalance + oldExpense.amount,
                  'lastUpdated': Timestamp.now(),
                });
              }
            });
          }
          // Apply to new wallet
          if (expense.walletId != null) {
            final newWalletRef = _firebaseService.walletsRef.doc(expense.walletId);
            await _firebaseService.firestore.runTransaction((transaction) async {
              final snapshot = await transaction.get(newWalletRef);
              if (snapshot.exists) {
                final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
                transaction.update(newWalletRef, {
                  'currentBalance': currentBalance - expense.amount,
                  'lastUpdated': Timestamp.now(),
                });
              }
            });
          }
        } else if (expense.walletId != null && oldExpense.amount != expense.amount) {
          final diff = expense.amount - oldExpense.amount;
          final walletRef = _firebaseService.walletsRef.doc(expense.walletId);
          await _firebaseService.firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(walletRef);
            if (snapshot.exists) {
              final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
              transaction.update(walletRef, {
                'currentBalance': currentBalance - diff,
                'lastUpdated': Timestamp.now(),
              });
            }
          });
        }
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('ExpenseProvider.updateExpense error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> deleteExpense(String id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final expense = _expenseList.where((e) => e.id == id).firstOrNull;

      await _firebaseService.deleteExpense(id);

      // Revert wallet balance
      if (expense != null && expense.walletId != null) {
        final walletRef = _firebaseService.walletsRef.doc(expense.walletId);
        await _firebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(walletRef);
          if (snapshot.exists) {
            final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
            transaction.update(walletRef, {
              'currentBalance': currentBalance + expense.amount,
              'lastUpdated': Timestamp.now(),
            });
          }
        });
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('ExpenseProvider.deleteExpense error: $e');
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _expenseList.clear();
    _subscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}