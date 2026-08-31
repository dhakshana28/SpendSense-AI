import '../../models/expense_model.dart';

class DetectedSubscription {
  final String name;
  final double monthlyCost;
  final String category;
  final bool isActive;
  final List<ExpenseModel> matchedExpenses;
  final DateTime lastDetected;
  final bool isUnused;
  final String? cancellationSuggestion;

  const DetectedSubscription({
    required this.name,
    required this.monthlyCost,
    required this.category,
    required this.isActive,
    required this.matchedExpenses,
    required this.lastDetected,
    this.isUnused = false,
    this.cancellationSuggestion,
  });
}

class SubscriptionDetector {
  static const Map<String, List<String>> _subscriptionKeywords = {
    'Netflix': ['netflix', 'netflix premium'],
    'Spotify': ['spotify', 'spotify premium'],
    'Amazon Prime': ['amazon prime', 'prime video', 'prime music'],
    'Disney+ Hotstar': ['hotstar', 'disney+ hotstar', 'disney plus'],
    'YouTube Premium': ['youtube premium', 'youtube music', 'yt premium'],
    'Zee5': ['zee5', 'zee 5'],
    'SonyLIV': ['sonyliv', 'sony liv'],
    'JioCinema': ['jiocinema', 'jio cinema'],
    'Gaana': ['gaana', 'gaana plus'],
    'Jio Music': ['jio music', 'jiomusic'],
    'Gym Membership': ['gym', 'gym membership', 'fitness', 'cult.fit', 'cultfit'],
    'Mobile Recharge': ['mobile recharge', 'phone recharge', 'prepaid', 'airtel', 'jio recharge', 'vi recharge'],
    'Internet': ['wifi', 'broadband', 'internet bill', 'jio fiber', 'airtel fiber'],
    'Cloud Storage': ['icloud', 'google drive', 'onedrive', 'dropbox', 'google one'],
    'Apple Music': ['apple music', 'apple music subscription'],
    'Microsoft 365': ['microsoft 365', 'office 365'],
    'Medium': ['medium membership'],
    'LinkedIn Premium': ['linkedin premium'],
    'ChatGPT Plus': ['chatgpt plus', 'chatgpt'],
    'Adobe Creative Cloud': ['adobe', 'creative cloud', 'photoshop', 'adobe premiere'],
    'Google One': ['google one', 'google storage'],
    'Amazon Music': ['amazon music', 'amazon music unlimited'],
    'Audible': ['audible', 'audible subscription'],
    'HBO Max': ['hbo max', 'hbo'],
    'Apple TV+': ['apple tv', 'apple tv+'],
    'Disney+': ['disney+', 'disney plus'],
    'Hulu': ['hulu'],
    'Paramount+': ['paramount+', 'paramount plus'],
    'Peacock': ['peacock'],
    'Crunchyroll': ['crunchyroll'],
    'Twitch': ['twitch', 'twitch prime'],
    'Canva Pro': ['canva pro', 'canva'],
    'Figma': ['figma'],
    'Notion': ['notion'],
    'Slack': ['slack'],
    'Zoom': ['zoom'],
    'Grammarly': ['grammarly'],
    'Duolingo Plus': ['duolingo plus', 'duolingo'],
    'Headspace': ['headspace'],
    'Calm': ['calm app', 'calm subscription'],
    'MyFitnessPal': ['myfitnesspal', 'my fitness pal'],
    'Strava': ['strava'],
    'Electricity Bill': ['electricity', 'electric bill', 'bseb', 'tneb', 'bescom', 'adani electricity'],
    'Water Bill': ['water bill', 'water supply', 'water charges'],
    'Gas Bill': ['gas bill', 'lpg', 'indane', 'hp gas', 'bharat gas'],
    'Insurance Premium': ['insurance', 'life insurance', 'health insurance', 'car insurance', 'bike insurance'],
    'Loan EMI': ['loan emi', 'emi', 'home loan', 'car loan', 'personal loan', 'education loan'],
    'Rent': ['rent', 'house rent', 'apartment rent'],
  };

  static List<DetectedSubscription> detect(List<ExpenseModel> expenses) {
    final subscriptions = <DetectedSubscription>[];
    if (expenses.length < 3) return subscriptions;

    final now = DateTime.now();

    for (final entry in _subscriptionKeywords.entries) {
      final name = entry.key;
      final keywords = entry.value;

      // Find expenses matching this subscription
      final matches = expenses.where((e) {
        final desc = e.description.toLowerCase();
        final cat = e.category.toLowerCase();
        return keywords.any((k) => desc.contains(k) || cat.contains(k));
      }).toList();

      if (matches.length < 2) continue;

      // Check if recurring (similar amounts at regular intervals)
      final sorted = List<ExpenseModel>.from(matches)
        ..sort((a, b) => a.date.compareTo(b.date));

      final amounts = sorted.map((e) => e.amount).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      final isRecurring = _isRecurring(sorted);

      if (isRecurring) {
        final lastThreeMonths = sorted.where((e) =>
            e.date.isAfter(now.subtract(const Duration(days: 90)))).toList();
        final isActive = lastThreeMonths.length >= 2;

        // Determine if subscription is unused (no recent activity in last 60 days)
        final lastActivity = sorted.last.date;
        final isUnused = now.difference(lastActivity).inDays > 60;

        // Generate cancellation suggestion
        String? cancellationSuggestion;
        if (isUnused) {
          cancellationSuggestion = 'No activity in the last ${now.difference(lastActivity).inDays} days. '
              'Consider cancelling to save ₹${avgAmount.toStringAsFixed(0)}/month '
              '(₹${(avgAmount * 12).toStringAsFixed(0)}/year).';
        }

        subscriptions.add(DetectedSubscription(
          name: name,
          monthlyCost: double.parse(avgAmount.toStringAsFixed(2)),
          category: _getCategoryForSubscription(name),
          isActive: isActive,
          matchedExpenses: sorted,
          lastDetected: sorted.last.date,
          isUnused: isUnused,
          cancellationSuggestion: cancellationSuggestion,
        ));
      }
    }

    subscriptions.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    return subscriptions;
  }

  static String _getCategoryForSubscription(String name) {
    if (name.contains('Gym') || name.contains('Fitness') || name.contains('Cult')) {
      return 'Fitness';
    }
    if (name.contains('Electricity') || name.contains('Water') || name.contains('Gas')) {
      return 'Utilities';
    }
    if (name.contains('Insurance')) {
      return 'Insurance';
    }
    if (name.contains('Loan') || name.contains('EMI')) {
      return 'Loans';
    }
    if (name.contains('Rent')) {
      return 'Rent';
    }
    if (name.contains('Recharge') || name.contains('Internet')) {
      return 'Bills';
    }
    return 'Entertainment';
  }

  static bool _isRecurring(List<ExpenseModel> sorted) {
    if (sorted.length < 2) return false;

    // Check if amounts are similar (within 20% variance)
    final amounts = sorted.map((e) => e.amount).toList();
    final avg = amounts.reduce((a, b) => a + b) / amounts.length;
    for (final amount in amounts) {
      if ((amount - avg).abs() / (avg > 0 ? avg : 1) > 0.2) {
        return false;
      }
    }

    // Check if dates are roughly monthly (25-35 day gaps)
    for (int i = 1; i < sorted.length; i++) {
      final daysDiff = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (daysDiff < 20 || daysDiff > 45) {
        // Still likely recurring if at least 2 monthly payments
        final monthlyCount = sorted.where((e) {
          final diff = e.date.difference(sorted.first.date).inDays;
          return diff >= 25 && diff <= 35;
        }).length;
        return monthlyCount >= 1;
      }
    }

    return true;
  }

  /// Calculate total monthly subscription cost.
  static double totalMonthlyCost(List<DetectedSubscription> subscriptions) {
    return subscriptions.fold(0.0, (sum, s) => sum + s.monthlyCost);
  }

  /// Calculate total annual subscription cost.
  static double totalAnnualCost(List<DetectedSubscription> subscriptions) {
    return totalMonthlyCost(subscriptions) * 12;
  }

  /// Get unused subscriptions that could be cancelled.
  static List<DetectedSubscription> getUnusedSubscriptions(List<DetectedSubscription> subscriptions) {
    return subscriptions.where((s) => s.isUnused).toList();
  }
}