import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/firebase/firebase_service.dart';

class WalletProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<WalletModel> _wallets = [];
  List<WalletTransactionModel> _transactions = [];
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription? _walletSubscription;
  StreamSubscription? _transactionSubscription;

  List<WalletModel> get wallets => _wallets;
  List<WalletTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalWalletBalance =>
      _wallets.fold(0.0, (value, w) => value + w.currentBalance);

  double get todayIncome {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.type == 'income' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .fold(0.0, (value, t) => value + t.amount);
  }

  double get todayExpense {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .fold(0.0, (value, t) => value + t.amount);
  }

  List<WalletTransactionModel> get recentTransactions {
    final sorted = List<WalletTransactionModel>.from(_transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(10).toList();
  }

  Map<String, double> get walletDistribution {
    final total = totalWalletBalance;
    if (total == 0) return {};
    return {
      for (final w in _wallets)
        w.name: total > 0 ? (w.currentBalance / total) * 100 : 0,
    };
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletSubscription?.cancel();
    _walletSubscription = _firebaseService.walletsRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _wallets = snapshot.docs
          .map((doc) => WalletModel.fromMap(doc.data(), doc.id))
          .toList();
      _wallets.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('WalletProvider subscription error: $error');
      _error = FirebaseService.getFriendlyError(error);
      notifyListeners();
    });

    _transactionSubscription?.cancel();
    _transactionSubscription = _firebaseService.walletTransactionsRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => WalletTransactionModel.fromMap(doc.data(), doc.id))
          .toList();
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }, onError: (error) {
      debugPrint('WalletProvider transaction subscription error: $error');
    });
  }

  Future<bool> addWallet(WalletModel wallet) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.addWallet(wallet);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('WalletProvider.addWallet error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateWallet(WalletModel wallet) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.updateWallet(wallet);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      debugPrint('WalletProvider.updateWallet error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteWallet(String id) async {
    try {
      await _firebaseService.deleteWallet(id);
    } catch (e) {
      debugPrint('WalletProvider.deleteWallet error: $e');
      rethrow;
    }
  }

  Future<void> updateWalletBalance(String walletId, double newBalance) async {
    try {
      final index = _wallets.indexWhere((w) => w.id == walletId);
      if (index == -1) return;
      final wallet = _wallets[index];
      final updated = wallet.copyWith(
        currentBalance: newBalance,
        lastUpdated: DateTime.now(),
      );
      await _firebaseService.updateWallet(updated);
    } catch (e) {
      debugPrint('WalletProvider.updateWalletBalance error: $e');
    }
  }

  Future<void> addWalletTransaction(WalletTransactionModel transaction) async {
    try {
      await _firebaseService.addWalletTransaction(transaction);
    } catch (e) {
      debugPrint('WalletProvider.addWalletTransaction error: $e');
      rethrow;
    }
  }

  Future<void> deleteWalletTransaction(String id) async {
    try {
      await _firebaseService.deleteWalletTransaction(id);
    } catch (e) {
      debugPrint('WalletProvider.deleteWalletTransaction error: $e');
      rethrow;
    }
  }

  WalletModel? getWalletById(String id) {
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  List<WalletTransactionModel> getWalletTransactions(String walletId) {
    return _transactions.where((t) => t.walletId == walletId).toList();
  }

  double getWalletBalance(String walletId) {
    final wallet = getWalletById(walletId);
    return wallet?.currentBalance ?? 0;
  }

  bool isDuplicateName(String name, {String? excludeId}) {
    return _wallets.any((w) =>
        w.name.toLowerCase() == name.toLowerCase() &&
        (excludeId == null || w.id != excludeId));
  }

  void clear() {
    _wallets.clear();
    _transactions.clear();
    _walletSubscription?.cancel();
    _transactionSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionSubscription?.cancel();
    super.dispose();
  }
}