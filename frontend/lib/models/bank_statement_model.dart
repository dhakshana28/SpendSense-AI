/// Represents a single transaction parsed from a bank statement.
class BankTransaction {
  final String id;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String category;
  final String merchant;
  final String referenceNumber;

  const BankTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.category,
    required this.merchant,
    this.referenceNumber = '',
  });

  bool get isExpense => debit > 0;
  bool get isIncome => credit > 0;
  double get amount => isExpense ? debit : credit;

  BankTransaction copyWith({
    String? id,
    DateTime? date,
    String? description,
    double? debit,
    double? credit,
    double? balance,
    String? category,
    String? merchant,
    String? referenceNumber,
  }) {
    return BankTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      referenceNumber: referenceNumber ?? this.referenceNumber,
    );
  }
}

/// Summary of a parsed bank statement.
class BankStatementSummary {
  final int totalTransactions;
  final int expenseCount;
  final int incomeCount;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final Map<String, double> categoryBreakdown;
  final List<BankTransaction> transactions;

  const BankStatementSummary({
    required this.totalTransactions,
    required this.expenseCount,
    required this.incomeCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.categoryBreakdown,
    required this.transactions,
  });
}