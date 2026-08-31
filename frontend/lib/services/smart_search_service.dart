import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/budget_model.dart';

class SearchResult {
  final String type;
  final dynamic data;
  final double score;

  const SearchResult({
    required this.type,
    required this.data,
    required this.score,
  });
}

class SmartSearchService {
  static List<SearchResult> search({
    required String query,
    required List<ExpenseModel> expenses,
    required List<IncomeModel> incomes,
    required List<BudgetModel> budgets,
  }) {
    final results = <SearchResult>[];
    final q = query.toLowerCase().trim();

    if (q.isEmpty) return results;

    // Natural language processing
    final filters = _parseQuery(q);

    // Search expenses
    for (final e in expenses) {
      double score = 0;

      // Category match
      if (filters['category'] != null && e.category.toLowerCase() == filters['category']) {
        score += 10;
      }

      // Amount filters
      if (filters['minAmount'] != null && e.amount >= filters['minAmount']!) {
        score += 5;
      }
      if (filters['maxAmount'] != null && e.amount <= filters['maxAmount']!) {
        score += 5;
      }

      // Text search
      if (e.description.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)) {
        score += 3;
      }

      // Time filters
      if (filters['month'] != null && e.date.month != filters['month']) {
        continue;
      }
      if (filters['year'] != null && e.date.year != filters['year']) {
        continue;
      }

      if (score > 0) {
        results.add(SearchResult(type: 'expense', data: e, score: score));
      }
    }

    // Search incomes
    for (final i in incomes) {
      double score = 0;
      if (i.description.toLowerCase().contains(q) || i.category.toLowerCase().contains(q)) {
        score += 3;
      }
      if (filters['month'] != null && i.date.month != filters['month']) continue;
      if (filters['year'] != null && i.date.year != filters['year']) continue;
      if (score > 0) results.add(SearchResult(type: 'income', data: i, score: score));
    }

    // Search budgets
    for (final b in budgets) {
      if (b.category.toLowerCase().contains(q)) {
        results.add(SearchResult(type: 'budget', data: b, score: 2));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static Map<String, dynamic> _parseQuery(String query) {
    final filters = <String, dynamic>{};

    // Category detection
    final categories = ['food', 'transport', 'shopping', 'bills', 'entertainment', 'health', 'education', 'travel', 'rent', 'investment'];
    for (final cat in categories) {
      if (query.contains(cat)) {
        filters['category'] = cat[0].toUpperCase() + cat.substring(1);
        break;
      }
    }

    // Amount detection
    final amountPattern = RegExp(r'above\s+₹?\s*(\d+)');
    final aboveMatch = amountPattern.firstMatch(query);
    if (aboveMatch != null) {
      filters['minAmount'] = double.tryParse(aboveMatch.group(1) ?? '0') ?? 0;
    }

    final belowPattern = RegExp(r'below\s+₹?\s*(\d+)');
    final belowMatch = belowPattern.firstMatch(query);
    if (belowMatch != null) {
      filters['maxAmount'] = double.tryParse(belowMatch.group(1) ?? '0') ?? 0;
    }

    // Time detection
    if (query.contains('last month')) {
      final now = DateTime.now();
      filters['month'] = now.month == 1 ? 12 : now.month - 1;
      filters['year'] = now.month == 1 ? now.year - 1 : now.year;
    } else if (query.contains('this month') || query.contains('current month')) {
      final now = DateTime.now();
      filters['month'] = now.month;
      filters['year'] = now.year;
    }

    // Month names
    const months = {'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6, 'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12};
    for (final entry in months.entries) {
      if (query.contains(entry.key)) {
        filters['month'] = entry.value;
        final yearMatch = RegExp(r'\d{4}').firstMatch(query);
        if (yearMatch != null) {
          filters['year'] = int.tryParse(yearMatch.group(0) ?? '') ?? DateTime.now().year;
        } else {
          filters['year'] = DateTime.now().year;
        }
        break;
      }
    }

    return filters;
  }
}