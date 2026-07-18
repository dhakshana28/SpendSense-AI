import 'package:flutter/material.dart';

import '../models/income_model.dart';

class IncomeProvider extends ChangeNotifier {
  final List<IncomeModel> _incomeList = [];

  List<IncomeModel> get incomeList => _incomeList;

  double get totalIncome =>
      _incomeList.fold(
        0,
        (sum, item) => sum + item.amount,
      );

  void addIncome(IncomeModel income) {
    _incomeList.add(income);
    notifyListeners();
  }

  void removeIncome(String id) {
    _incomeList.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void clear() {
    _incomeList.clear();
    notifyListeners();
  }
}