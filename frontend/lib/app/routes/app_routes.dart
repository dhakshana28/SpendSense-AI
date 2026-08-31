import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';

import '../../screens/main_shell_screen.dart';
import '../../screens/income/income_screen.dart';
import '../../screens/expense/expense_screen.dart';
import '../../screens/budget/budget_screen.dart';
import '../../screens/goals/goals_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/savings/savings_analytics_screen.dart';
import '../../screens/ai/ai_dashboard_screen.dart';
import '../../screens/ai_chat_screen.dart';
import '../../screens/ai/ai_insights_screen.dart';
import '../../screens/ai/ai_alerts_screen.dart';
import '../../screens/ai/financial_health_screen.dart';
import '../../screens/ai/subscription_detail_screen.dart';
import '../../screens/bank_statement_import_screen.dart';

class AppRoutes {
  // Route Names
  static const String login = "/";
  static const String register = "/register";
  static const String forgotPassword = "/forgot-password";

  static const String dashboard = "/dashboard";
  static const String income = "/income";
  static const String expense = "/expense";
  static const String budget = "/budget";
  static const String goals = "/goals";
  static const String reports = "/reports";
  static const String profile = "/profile";
  static const String savingsAnalytics = "/savings-analytics";

  static const String aiDashboard = "/ai-dashboard";
  static const String aiChat = "/ai-chat";
  static const String aiInsights = "/ai-insights";
  static const String aiAlerts = "/ai-alerts";
  static const String financialHealth = "/financial-health";
  static const String bankStatementImport = "/bank-statement-import";
  static const String subscriptionDetail = "/subscription-detail";

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),

    dashboard: (context) => const MainShellScreen(),
    income: (context) => const IncomeScreen(),
    expense: (context) => const ExpenseScreen(),
    budget: (context) => const BudgetScreen(),
    goals: (context) => const GoalsScreen(),
    reports: (context) => const ReportsScreen(),
    profile: (context) => const ProfileScreen(),
    savingsAnalytics: (context) => const SavingsAnalyticsScreen(),

    aiDashboard: (context) => const AIDashboardScreen(),
    aiChat: (context) => const AIChatScreen(),
    aiInsights: (context) => const AIInsightsScreen(),
    aiAlerts: (context) => const AIAlertsScreen(),
    financialHealth: (context) => const FinancialHealthScreen(),
    bankStatementImport: (context) => const BankStatementImportScreen(),
    subscriptionDetail: (context) => const SubscriptionDetailScreen(),
  };
}