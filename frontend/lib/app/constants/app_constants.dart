class AppConstants {
  // ===============================
  // App Information
  // ===============================

  static const String appName = "SpendSense AI";
  static const String appVersion = "1.0.0";

  // ===============================
  // Currency
  // ===============================

  static const String currency = "₹";

  // ===============================
  // Gemini AI
  // ===============================

  static const String geminiModel = "gemini-3.5-flash-lite";

  // Replace with your API key later
  static const String geminiApiKey = "";

  // ===============================
  // Firestore Collections
  // ===============================

  static const String usersCollection = "users";
  static const String incomeCollection = "income";
  static const String expenseCollection = "expenses";
  static const String budgetCollection = "budgets";
  static const String goalsCollection = "goals";
  static const String reportsCollection = "reports";
  static const String notificationsCollection = "notifications";
  static const String walletsCollection = "wallets";
  static const String walletTransactionsCollection = "wallet_transactions";
  static const String savingsSummaryCollection = "savings_summary";

  // ===============================
  // Shared Preferences Keys
  // ===============================

  static const String isLoggedIn = "isLoggedIn";
  static const String userId = "userId";
  static const String userEmail = "userEmail";
  static const String userName = "userName";
  static const String themeMode = "themeMode";

  // ===============================
  // Financial Health Score
  // ===============================

  static const int excellentScore = 90;
  static const int goodScore = 75;
  static const int averageScore = 60;
  static const int poorScore = 40;

  // ===============================
  // Budget Defaults
  // ===============================

  static const double defaultMonthlyBudget = 10000.0;
  static const double defaultSavingsGoal = 5000.0;

  // ===============================
  // Categories
  // ===============================

  static const List<String> expenseCategories = [
    "Food",
    "Transport",
    "Shopping",
    "Bills",
    "Entertainment",
    "Health",
    "Education",
    "Travel",
    "Rent",
    "Investment",
    "Others",
  ];

  static const List<String> incomeCategories = [
    "Salary",
    "Freelancing",
    "Business",
    "Bonus",
    "Interest",
    "Gift",
    "Investment",
    "Others",
  ];

  // ===============================
  // Date Formats
  // ===============================

  static const String dateFormat = "dd/MM/yyyy";
  static const String monthFormat = "MMMM yyyy";

  // ===============================
  // AI Messages
  // ===============================

  static const String welcomeMessage =
      "Welcome to SpendSense AI! Let's manage your finances smarter.";

  static const String aiPrompt =
      "Analyze my spending habits and provide personalized savings suggestions.";
}