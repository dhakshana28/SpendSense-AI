import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/income_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/firebase/firebase_service.dart';

class IncomeProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final _uuid = const Uuid();
  
  List<IncomeModel> _incomeList = [];
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription? _subscription;

  List<IncomeModel> get incomeList => _incomeList;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalIncome =>
      _incomeList.fold(0.0, (value, item) => value + item.amount);

  double get monthlyIncome {
    final now = DateTime.now();
    return _incomeList
        .where((item) =>
            item.date.month == now.month && item.date.year == now.year)
        .fold(0.0, (value, item) => value + item.amount);
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription?.cancel();
    _subscription = _firebaseService.incomeRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _incomeList = snapshot.docs
          .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
          .toList();
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('IncomeProvider subscription error: $error');
      _error = FirebaseService.getFriendlyError(error);
      notifyListeners();
    });
  }

  Future<bool> addIncome(IncomeModel income) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.addIncome(income);

      // Update wallet balance if linked
      if (income.walletId != null) {
        final walletRef = _firebaseService.walletsRef.doc(income.walletId);
        await _firebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(walletRef);
          if (snapshot.exists) {
            final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
            transaction.update(walletRef, {
              'currentBalance': currentBalance + income.amount,
              'lastUpdated': Timestamp.now(),
            });
          }
        });

        // Add wallet transaction record
        final wt = WalletTransactionModel(
          id: _uuid.v4(),
          userId: income.userId,
          walletId: income.walletId!,
          walletName: income.walletName ?? '',
          type: 'income',
          amount: income.amount,
          category: income.category,
          description: income.description,
          referenceId: income.id,
          date: income.date,
          createdAt: DateTime.now(),
        );
        await _firebaseService.addWalletTransaction(wt);
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('IncomeProvider.addIncome error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateIncome(IncomeModel income) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      // Get old income to calculate balance difference
      final oldIncome = _incomeList.where((i) => i.id == income.id).firstOrNull;
      
      await _firebaseService.updateIncome(income);

      // Update wallet balances if linked
      if (oldIncome != null) {
        // If wallet changed, revert old wallet and update new
        if (oldIncome.walletId != income.walletId) {
          // Revert old wallet
          if (oldIncome.walletId != null) {
            final oldWalletRef = _firebaseService.walletsRef.doc(oldIncome.walletId);
            await _firebaseService.firestore.runTransaction((transaction) async {
              final snapshot = await transaction.get(oldWalletRef);
              if (snapshot.exists) {
                final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
                transaction.update(oldWalletRef, {
                  'currentBalance': currentBalance - oldIncome.amount,
                  'lastUpdated': Timestamp.now(),
                });
              }
            });
          }
          // Apply to new wallet
          if (income.walletId != null) {
            final newWalletRef = _firebaseService.walletsRef.doc(income.walletId);
            await _firebaseService.firestore.runTransaction((transaction) async {
              final snapshot = await transaction.get(newWalletRef);
              if (snapshot.exists) {
                final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
                transaction.update(newWalletRef, {
                  'currentBalance': currentBalance + income.amount,
                  'lastUpdated': Timestamp.now(),
                });
              }
            });
          }
        } else if (income.walletId != null && oldIncome.amount != income.amount) {
          // Same wallet, amount changed
          final diff = income.amount - oldIncome.amount;
          final walletRef = _firebaseService.walletsRef.doc(income.walletId);
          await _firebaseService.firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(walletRef);
            if (snapshot.exists) {
              final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
              transaction.update(walletRef, {
                'currentBalance': currentBalance + diff,
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
      debugPrint('IncomeProvider.updateIncome error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> deleteIncome(String id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final income = _incomeList.where((i) => i.id == id).firstOrNull;

      await _firebaseService.deleteIncome(id);

      // Revert wallet balance
      if (income != null && income.walletId != null) {
        final walletRef = _firebaseService.walletsRef.doc(income.walletId);
        await _firebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(walletRef);
          if (snapshot.exists) {
            final currentBalance = (snapshot.data()?['currentBalance'] ?? 0).toDouble();
            transaction.update(walletRef, {
              'currentBalance': currentBalance - income.amount,
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
      debugPrint('IncomeProvider.deleteIncome error: $e');
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _incomeList.clear();
    _subscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}