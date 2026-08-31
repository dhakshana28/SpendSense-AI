import 'package:flutter/material.dart';

import '../widgets/navigation_drawer.dart';
import '../widgets/global_alerts_banner.dart';
import 'dashboard/dashboard_screen.dart';
import 'income/income_screen.dart';
import 'expense/expense_screen.dart';
import 'budget/budget_screen.dart';
import 'reports/reports_screen.dart';
import 'profile/profile_screen.dart';
import 'wallets/wallet_dashboard_screen.dart';
import 'savings/savings_analytics_screen.dart';
import 'ai/ai_dashboard_screen.dart';
import 'ai_chat_screen.dart';
import 'ai/ai_insights_screen.dart';
import 'ai/financial_health_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  final List<Widget?> _pageCache = List<Widget?>.filled(12, null);
  static const List<Widget Function()> _pageBuilders = [
    DashboardScreen.new,
    WalletDashboardScreen.new,
    SavingsAnalyticsScreen.new,
    IncomeScreen.new,
    ExpenseScreen.new,
    BudgetScreen.new,
    ReportsScreen.new,
    ProfileScreen.new,
    AIDashboardScreen.new,
    AIChatScreen.new,
    AIInsightsScreen.new,
    FinancialHealthScreen.new,
  ];

  Widget _getPage(int index) {
    // Lazy-load pages: only build when first visited.
    return _pageCache[index] ??= _pageBuilders[index]();
  }

  String _getPageTitle(int index) {
    const titles = [
      'Dashboard',
      'Wallet Dashboard',
      'Savings Analytics',
      'Income',
      'Expenses',
      'Budget',
      'Reports',
      'Profile',
      'AI Dashboard',
      'AI Chat',
      'AI Insights',
      'Financial Health',
    ];
    if (index < 0 || index >= titles.length) return 'SpendSense AI';
    return titles[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
        elevation: 0,
        title: Text(
          _getPageTitle(_currentIndex),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppNavigationDrawer(
        currentIndex: _currentIndex,
        onItemSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      // Lazy-load pages: only build the current page when it is first visited.
      // Previously used IndexedStack which eagerly built ALL pages at startup,
      // causing AI Insights to subscribe to Firestore and fire Gemini requests
      // even when it was never opened. This caused noticeable lag.
      body: Column(
        children: [
          // Global budget alerts banner (visible on all pages).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GlobalAlertsBanner(),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _getPage(_currentIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
