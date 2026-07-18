import 'package:flutter/material.dart';

import '../models/budget_model.dart';

class BudgetProvider extends ChangeNotifier {
  final List<BudgetModel> _budgets = [];

  List<BudgetModel> get budgets => _budgets;

  void addBudget(BudgetModel budget) {
    _budgets.add(budget);
    notifyListeners();
  }

  void removeBudget(String id) {
    _budgets.removeWhere(
      (element) => element.id == id,
    );

    notifyListeners();
  }

  BudgetModel? getBudget(String category) {
    try {
      return _budgets.firstWhere(
        (e) => e.category == category,
      );
    } catch (e) {
      debugPrint('getBudget: No budget found for category "$category": $e');
      return null;
    }
  }

  void clear() {
    _budgets.clear();
    notifyListeners();
  }
}