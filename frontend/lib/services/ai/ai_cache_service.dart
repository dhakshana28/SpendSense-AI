import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AICacheEntry {
  final String response;
  final DateTime cachedAt;
  final String dataHash;

  const AICacheEntry({
    required this.response,
    required this.cachedAt,
    required this.dataHash,
  });

  bool isValid({required String currentHash, Duration maxAge = const Duration(hours: 1)}) {
    return dataHash == currentHash &&
        DateTime.now().difference(cachedAt) < maxAge;
  }

  Map<String, dynamic> toJson() => {
        'response': response,
        'cachedAt': cachedAt.toIso8601String(),
        'dataHash': dataHash,
      };

  factory AICacheEntry.fromJson(Map<String, dynamic> json) => AICacheEntry(
        response: json['response'] as String? ?? '',
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        dataHash: json['dataHash'] as String? ?? '',
      );
}

class AICacheService {
  static const String _prefix = 'ai_cache_';

  static String _computeDataHash({
    required double totalIncome,
    required double totalExpense,
    required int expenseCount,
    required int budgetCount,
    required int goalCount,
  }) {
    final input = '$totalIncome|$totalExpense|$expenseCount|$budgetCount|$goalCount';
    return _simpleHash(input);
  }

  static String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = (hash * 31 + input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static String _buildDataHash({
    required List<dynamic> incomes,
    required List<dynamic> expenses,
    required List<dynamic> budgets,
    required List<dynamic> goals,
  }) {
    final totalIncome = incomes.fold(0.0, (sum, i) => sum + (i.amount ?? i['amount'] ?? 0));
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + (e.amount ?? e['amount'] ?? 0));
    return _computeDataHash(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      expenseCount: expenses.length,
      budgetCount: budgets.length,
      goalCount: goals.length,
    );
  }

  static Future<String?> getCachedResponse({
    required String cacheKey,
    required List<dynamic> incomes,
    required List<dynamic> expenses,
    required List<dynamic> budgets,
    required List<dynamic> goals,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_prefix$cacheKey');
      if (jsonStr == null) {
        debugPrint('AI Cache Miss: $cacheKey (no cached entry)');
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entry = AICacheEntry.fromJson(json);
      final currentHash = _buildDataHash(
        incomes: incomes,
        expenses: expenses,
        budgets: budgets,
        goals: goals,
      );

      if (entry.isValid(currentHash: currentHash)) {
        debugPrint('AI Cache Hit: $cacheKey');
        return entry.response;
      }
      debugPrint('AI Cache Miss: $cacheKey (data changed or expired)');
    } catch (_) {}
    return null;
  }

  static Future<void> cacheResponse({
    required String cacheKey,
    required String response,
    required List<dynamic> incomes,
    required List<dynamic> expenses,
    required List<dynamic> budgets,
    required List<dynamic> goals,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentHash = _buildDataHash(
        incomes: incomes,
        expenses: expenses,
        budgets: budgets,
        goals: goals,
      );
      final entry = AICacheEntry(
        response: response,
        cachedAt: DateTime.now(),
        dataHash: currentHash,
      );
      await prefs.setString('$_prefix$cacheKey', jsonEncode(entry.toJson()));
    } catch (_) {}
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}