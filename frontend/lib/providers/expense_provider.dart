import 'package:flutter/material.dart';

import '../models/expense_model.dart';

class ExpenseProvider extends ChangeNotifier {
  final List<ExpenseModel> _expenses = [];

  List<ExpenseModel> get expenses => _expenses;

  double get totalExpense =>
      _expenses.fold(
        0,
        (sum, item) => sum + item.amount,
      );

  void addExpense(ExpenseModel expense) {
    _expenses.add(expense);
    notifyListeners();
  }

  void deleteExpense(String id) {
    _expenses.removeWhere(
      (element) => element.id == id,
    );

    notifyListeners();
  }

  void clear() {
    _expenses.clear();
    notifyListeners();
  }
}