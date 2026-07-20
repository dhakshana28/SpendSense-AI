import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/income_model.dart';
import '../services/firebase/firebase_service.dart';

class IncomeProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<IncomeModel> _incomeList = [];
  final bool _isLoading = false;
  String? _error;
  StreamSubscription? _subscription;

  List<IncomeModel> get incomeList => _incomeList;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalIncome =>
      _incomeList.fold(0, (sum, item) => sum + item.amount);

  double get monthlyIncome {
    final now = DateTime.now();
    final monthly = _incomeList.where((i) =>
        i.date.month == now.month && i.date.year == now.year);
    return monthly.fold(0, (sum, item) => sum + item.amount);
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription = _firebaseService.incomeRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _incomeList = snapshot.docs
          .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
          .toList();
      _error = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint('IncomeProvider subscription error: $error');
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> addIncome(IncomeModel income) async {
    try {
      await _firebaseService.addIncome(income);
    } catch (e) {
      debugPrint('IncomeProvider.addIncome error: $e');
      rethrow;
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    try {
      await _firebaseService.updateIncome(income);
    } catch (e) {
      debugPrint('IncomeProvider.updateIncome error: $e');
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    try {
      await _firebaseService.deleteIncome(id);
    } catch (e) {
      debugPrint('IncomeProvider.deleteIncome error: $e');
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