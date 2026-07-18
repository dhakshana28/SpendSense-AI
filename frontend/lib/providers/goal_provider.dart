import 'package:flutter/material.dart';

import '../models/goal_model.dart';

class GoalProvider extends ChangeNotifier {
  final List<GoalModel> _goals = [];

  List<GoalModel> get goals => _goals;

  void addGoal(GoalModel goal) {
    _goals.add(goal);
    notifyListeners();
  }

  void removeGoal(String id) {
    _goals.removeWhere(
      (element) => element.id == id,
    );

    notifyListeners();
  }

  double get totalSavings {
    return _goals.fold(
      0,
      (sum, goal) => sum + goal.savedAmount,
    );
  }

  void clear() {
    _goals.clear();
    notifyListeners();
  }
}