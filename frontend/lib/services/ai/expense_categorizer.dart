class ExpenseCategorizer {
  static const Map<String, List<String>> _keywordMap = {
    'Food': ['pizza', 'burger', 'restaurant', 'zomato', 'swiggy', 'dinner', 'lunch', 'breakfast', 'cafe', 'coffee', 'food', 'grocery', 'groceries', 'snack', 'meal', 'eat', 'dining', 'dominos', 'mcdonalds', 'kfc', 'subway', 'biryani', 'pasta', 'sandwich', 'juice', 'bakery', 'sweets', 'ice cream', 'chocolate'],
    'Transport': ['uber', 'ola', 'cab', 'taxi', 'bus', 'train', 'metro', 'petrol', 'fuel', 'diesel', 'gas', 'toll', 'parking', 'auto', 'rickshaw', 'flight', 'airplane', 'travel', 'commute', 'transport'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'amazon pay', 'shopping', 'clothes', 'dress', 'shoe', 'electronics', 'mobile', 'gadget', 'online shopping', 'meesho', 'ajio', 'nykaa', 'zara', 'hm', 'pantaloons', 'mall', 'purchase'],
    'Bills': ['electricity', 'electric', 'bill', 'water', 'wifi', 'internet', 'broadband', 'phone bill', 'mobile recharge', 'recharge', 'rent', 'maintenance', 'society', 'gas bill', 'utility'],
    'Entertainment': ['netflix', 'amazon prime', 'prime video', 'hotstar', 'disney', 'youtube premium', 'spotify', 'gaana', 'jio music', 'movie', 'cinema', 'imax', 'game', 'gaming', 'xbox', 'playstation', 'pubg', 'free fire', 'concert', 'show', 'theatre', 'zee5', 'sonyliv', 'voot'],
    'Health': ['hospital', 'doctor', 'clinic', 'medicine', 'pharmacy', 'medical', 'dentist', 'eye checkup', 'health', 'fitness', 'gym', 'yoga', 'diagnostic', 'blood test', 'insurance', 'health insurance', 'ayurveda'],
    'Education': ['school', 'college', 'university', 'course', 'udemy', 'coursera', 'unacademy', 'byjus', 'vedantu', 'book', 'ebook', 'stationery', 'exam', 'fee', 'tuition', 'class', 'training', 'learning', 'skill'],
    'Travel': ['hotel', 'booking', 'trip', 'goibibo', 'makemytrip', 'irctc', 'oyo', 'airbnb', 'vacation', 'holiday', 'tour', 'sightseeing', 'resort', 'homestay', 'travel'],
    'Rent': ['rent', 'house rent', 'flat rent', 'room rent', 'property rent'],
    'Investment': ['mutual fund', 'sip', 'stock', 'share', 'investment', 'fd', 'fixed deposit', 'rd', 'recurring deposit', 'trading', 'dem', 'nps', 'ppf', 'gold', 'crypto', 'bitcoin'],
  };

  static const Map<String, List<String>> _categoryKeywords = {
    'Food': ['food', 'eat', 'meal', 'grocery', 'restaurant', 'dine'],
    'Transport': ['transport', 'travel', 'commute', 'fuel', 'vehicle'],
    'Shopping': ['shop', 'buy', 'purchase', 'retail', 'apparel'],
    'Bills': ['bill', 'utility', 'recharge', 'payment', 'fee'],
    'Entertainment': ['entertain', 'movie', 'game', 'music', 'stream'],
    'Health': ['health', 'medical', 'fitness', 'wellness', 'care'],
    'Education': ['education', 'learn', 'study', 'course', 'academic'],
    'Travel': ['trip', 'hotel', 'vacation', 'tour', 'booking'],
    'Rent': ['rent'],
    'Investment': ['invest', 'saving', 'stock', 'fund', 'sip'],
    'Others': [],
  };

  static String categorize(String description, {String? title}) {
    final text = '$title $description'.toLowerCase().trim();
    if (text.isEmpty) return 'Others';

    // Score-based categorization
    final scores = <String, int>{};
    for (final entry in _keywordMap.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          score += keyword.length;
        }
      }
      if (score > 0) {
        scores[entry.key] = score;
      }
    }

    // Also check category-level keywords
    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          score += 5;
        }
      }
      if (score > 0) {
        scores[entry.key] = (scores[entry.key] ?? 0) + score;
      }
    }

    if (scores.isEmpty) return 'Others';

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  static List<String> suggestCategories() {
    return _keywordMap.keys.toList();
  }
}