import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/savings_summary_model.dart';
import '../services/firebase/firebase_service.dart';

class SavingsProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _incomeSubscription;
  StreamSubscription? _expenseSubscription;
  StreamSubscription? _savingsSubscription;

  List<IncomeModel> _incomes = [];
  List<ExpenseModel> _expenses = [];
  SavingsSummaryModel? _savingsSummary;
  final bool _isLoading = false;
  String? _error;

  List<IncomeModel> get incomes => _incomes;
  List<ExpenseModel> get expenses => _expenses;
  SavingsSummaryModel? get savingsSummary => _savingsSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cached computed values
  double? _cachedCurrentSavings;
  double? _cachedTotalIncome;
  double? _cachedTotalExpenses;
  DateTime? _lastCacheUpdate;

  bool get _isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < const Duration(seconds: 1);
  }

  void _invalidateCache() {
    _cachedCurrentSavings = null;
    _cachedTotalIncome = null;
    _cachedTotalExpenses = null;
    _lastCacheUpdate = DateTime.now();
  }

  double get currentSavings {
    if (_cachedCurrentSavings != null && _isCacheValid) return _cachedCurrentSavings!;
    final totalIncome = _incomes.fold<double>(0, (sum, i) => sum + i.amount);
    final totalExpense = _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    _cachedCurrentSavings = totalIncome - totalExpense;
    return _cachedCurrentSavings!;
  }

  double get totalIncome {
    if (_cachedTotalIncome != null && _isCacheValid) return _cachedTotalIncome!;
    _cachedTotalIncome = _incomes.fold<double>(0, (sum, i) => sum + i.amount);
    return _cachedTotalIncome!;
  }

  double get totalExpenses {
    if (_cachedTotalExpenses != null && _isCacheValid) return _cachedTotalExpenses!;
    _cachedTotalExpenses = _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    return _cachedTotalExpenses!;
  }

  double get monthlySavings {
    final now = DateTime.now();
    final monthlyIncome = _incomes
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .fold<double>(0, (sum, i) => sum + i.amount);
    final monthlyExpense = _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0, (sum, e) => sum + e.amount);
    return monthlyIncome - monthlyExpense;
  }

  double get monthlyIncome {
    final now = DateTime.now();
    return _incomes
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .fold<double>(0, (sum, i) => sum + i.amount);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  double get yearlySavings {
    final now = DateTime.now();
    final yearlyIncome = _incomes
        .where((i) => i.date.year == now.year)
        .fold<double>(0, (sum, i) => sum + i.amount);
    final yearlyExpense = _expenses
        .where((e) => e.date.year == now.year)
        .fold<double>(0, (sum, e) => sum + e.amount);
    return yearlyIncome - yearlyExpense;
  }

  double get savingsPercentage {
    final income = totalIncome;
    if (income == 0) return 0;
    return ((currentSavings / income) * 100).clamp(0, 100);
  }

  double get savingsGrowth {
    if (_savingsSummary == null) return 0;
    final previous = _savingsSummary!.currentSavings;
    if (previous == 0) return currentSavings > 0 ? 100 : 0;
    return ((currentSavings - previous) / previous) * 100;
  }

  Map<String, double> get monthlySavingsTrend {
    final now = DateTime.now();
    final trend = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthIncome = _incomes
          .where((inc) =>
              inc.date.month == month.month && inc.date.year == month.year)
          .fold<double>(0, (sum, inc) => sum + inc.amount);
      final monthExpense = _expenses
          .where((exp) =>
              exp.date.month == month.month && exp.date.year == month.year)
          .fold<double>(0, (sum, exp) => sum + exp.amount);
      final monthName = _getMonthAbbr(month.month);
      trend[monthName] = monthIncome - monthExpense;
    }
    return trend;
  }

  Map<String, double> get walletWiseSavings => {};

  double get savingsGoalProgress {
    final total = totalIncome;
    if (total == 0) return 0;
    return (currentSavings / total).clamp(0.0, 1.0);
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _incomeSubscription?.cancel();
    _expenseSubscription?.cancel();
    _savingsSubscription?.cancel();

    // Combine income and expense streams to minimize duplicate rebuilds.
    _incomeSubscription = _firebaseService.incomeRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _incomes = snapshot.docs
          .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
          .toList();
      _invalidateCache();
      _debouncedSave();
      notifyListeners();
    }, onError: (error) {
      debugPrint('SavingsProvider income subscription error: $error');
      _error = FirebaseService.getFriendlyError(error);
      notifyListeners();
    });

    _expenseSubscription = _firebaseService.expensesRef
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      _invalidateCache();
      _debouncedSave();
      notifyListeners();
    }, onError: (error) {
      debugPrint('SavingsProvider expense subscription error: $error');
      _error = FirebaseService.getFriendlyError(error);
      notifyListeners();
    });

    _savingsSubscription = _firebaseService.savingsSummaryRef
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _savingsSummary =
            SavingsSummaryModel.fromMap(snapshot.data()!, snapshot.id);
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint('SavingsProvider summary subscription error: $error');
    });
  }

  Timer? _saveTimer;
  DateTime? _lastSavedAt;
  double _lastSavedSavings = 0;

  void _debouncedSave() {
    _saveTimer?.cancel();
    // Only save if savings actually changed or enough time passed
    final currentSavingsValue = currentSavings;
    final shouldSave = _lastSavedAt == null ||
        DateTime.now().difference(_lastSavedAt!) > const Duration(seconds: 5) ||
        (currentSavingsValue - _lastSavedSavings).abs() > 0.01;

    if (shouldSave) {
      _saveTimer = Timer(const Duration(milliseconds: 500), () {
        _calculateAndSave();
        _lastSavedAt = DateTime.now();
        _lastSavedSavings = currentSavings;
      });
    }
  }

  Future<void> _calculateAndSave() async {
    try {
      final now = DateTime.now();
      final summary = SavingsSummaryModel(
        id: FirebaseAuth.instance.currentUser?.uid ?? '',
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        currentSavings: currentSavings,
        monthlySavings: monthlySavings,
        yearlySavings: yearlySavings,
        savingsPercentage: savingsPercentage,
        savingsGrowth: savingsGrowth,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        lastUpdated: now,
        createdAt: _savingsSummary?.createdAt ?? now,
      );
      await _firebaseService.saveSavingsSummary(summary);
    } catch (e) {
      debugPrint('SavingsProvider._calculateAndSave error: $e');
    }
  }

  void clear() {
    _incomes.clear();
    _expenses.clear();
    _savingsSummary = null;
    _incomeSubscription?.cancel();
    _expenseSubscription?.cancel();
    _savingsSubscription?.cancel();
    _saveTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _incomeSubscription?.cancel();
    _expenseSubscription?.cancel();
    _savingsSubscription?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}