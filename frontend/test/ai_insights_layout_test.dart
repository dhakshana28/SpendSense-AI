import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/screens/ai/ai_insights_screen.dart';
import 'package:frontend/providers/income_provider.dart';
import 'package:frontend/providers/expense_provider.dart';
import 'package:frontend/providers/budget_provider.dart';
import 'package:frontend/providers/goal_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/ai_provider.dart';
import 'package:frontend/models/expense_model.dart';
import 'package:frontend/models/income_model.dart';
import 'package:frontend/models/budget_model.dart';
import 'package:frontend/services/ai/health_score.dart';
import 'package:frontend/services/ai/savings_suggester.dart';

class TestIncomeProvider extends IncomeProvider {
  final List<IncomeModel> _testList;
  TestIncomeProvider(this._testList);

  @override
  List<IncomeModel> get incomeList => _testList;
}

class TestExpenseProvider extends ExpenseProvider {
  final List<ExpenseModel> _testList;
  TestExpenseProvider(this._testList);

  @override
  List<ExpenseModel> get expenses => _testList;
}

class TestBudgetProvider extends BudgetProvider {
  final List<BudgetModel> _testList;
  TestBudgetProvider(this._testList);

  @override
  List<BudgetModel> get budgets => _testList;
}

class TestAIProvider extends AIProvider {
  final HealthScoreResult? _testHealthScore;
  final List<SavingsSuggestion> _testSuggestions;

  TestAIProvider({
    HealthScoreResult? healthScore,
    List<SavingsSuggestion> suggestions = const [],
  })  : _testHealthScore = healthScore,
        _testSuggestions = suggestions;

  @override
  HealthScoreResult? get healthScore => _testHealthScore;

  @override
  List<SavingsSuggestion> get suggestions => _testSuggestions;
}

void main() {
  Widget buildTestWidget({
    required Size screenSize,
    TextScaler textScaler = TextScaler.noScaling,
    List<IncomeModel> incomes = const [],
    List<ExpenseModel> expenses = const [],
    List<BudgetModel> budgets = const [],
    HealthScoreResult? healthScore,
    List<SavingsSuggestion> suggestions = const [],
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        textScaler: textScaler,
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<IncomeProvider>(create: (_) => TestIncomeProvider(incomes)),
          ChangeNotifierProvider<ExpenseProvider>(create: (_) => TestExpenseProvider(expenses)),
          ChangeNotifierProvider<BudgetProvider>(create: (_) => TestBudgetProvider(budgets)),
          ChangeNotifierProvider<GoalProvider>(create: (_) => GoalProvider()),
          ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
          ChangeNotifierProvider<AIProvider>(create: (_) => TestAIProvider(
            healthScore: healthScore,
            suggestions: suggestions,
          )),
        ],
        child: const MaterialApp(
          home: AIInsightsScreen(),
        ),
      ),
    );
  }

  group('AIInsightsScreen Layout & Overflow Verification', () {
    final now = DateTime.now();

    final testIncomes = [
      IncomeModel(
        id: 'inc_1',
        userId: 'u1',
        source: 'Executive Enterprise Salary Bonus Retainer',
        amount: 250000.0,
        date: now,
        createdAt: now,
        category: 'Corporate Enterprise Salary',
        description: 'Monthly Salary Credit from Tech Corp',
      ),
    ];

    final testExpenses = [
      ExpenseModel(
        id: 'exp_1',
        userId: 'u1',
        category: 'Extremely Long Category Name For Testing Responsive Layout Constraints',
        amount: 145000.0,
        date: now,
        createdAt: now,
        description: 'Large Luxury Shopping Transaction',
        paymentMethod: 'Credit Card',
      ),
      ExpenseModel(
        id: 'exp_2',
        userId: 'u1',
        category: 'Food, Dining & Gourmet Groceries Delivery',
        amount: 45000.0,
        date: now,
        createdAt: now,
        description: 'Restaurant dining',
        paymentMethod: 'UPI',
      ),
      ExpenseModel(
        id: 'exp_3',
        userId: 'u1',
        category: 'Home Improvement, Furniture & Maintenance',
        amount: 32000.0,
        date: now,
        createdAt: now,
        description: 'Interior renovation',
        paymentMethod: 'Net Banking',
      ),
    ];

    final testBudgets = [
      BudgetModel(
        id: 'b1',
        userId: 'u1',
        category: 'Entertainment, Live Events & Digital Streaming Subscriptions',
        budgetAmount: 15000.0,
        spentAmount: 22500.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
    ];

    final testHealth = FinancialHealthScoreCalculator.calculate(
      incomes: testIncomes,
      expenses: testExpenses,
      budgets: testBudgets,
      goals: const [],
    );

    final testSuggestions = [
      const SavingsSuggestion(
        title: 'Optimize Ultra-High Entertainment Subscriptions',
        description: 'Cancel unused premium streaming platforms to save money.',
        potentialSavings: 3500.0,
        category: 'Entertainment & Subscriptions',
        priority: SuggestionPriority.high,
      ),
      const SavingsSuggestion(
        title: 'Dine-Out & Delivery Optimization',
        description: 'Cook at home on weekdays to reduce high takeout spending.',
        potentialSavings: 8000.0,
        category: 'Food & Dining',
        priority: SuggestionPriority.medium,
      ),
    ];

    testWidgets('Renders empty data state without any overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(screenSize: const Size(360, 800)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No Financial Data Yet'), findsOneWidget);
    });

    testWidgets('Renders on standard 360px screen with zero overflow errors across all sections', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(360, 800),
          incomes: testIncomes,
          expenses: testExpenses,
          budgets: testBudgets,
          healthScore: testHealth,
          suggestions: testSuggestions,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Financial Health & Cash Flow'), findsOneWidget);
      expect(find.text('Highest-Spending Categories'), findsOneWidget);

      // Scroll to render bottom sections (Savings, Budget, Tips)
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Potential Savings & Subscriptions'), findsOneWidget);
    });

    testWidgets('Renders on narrow 320px phone screen with long texts without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(320, 640),
          incomes: testIncomes,
          expenses: testExpenses,
          budgets: testBudgets,
          healthScore: testHealth,
          suggestions: testSuggestions,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Scroll to render bottom sections
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders on extreme narrow 280px phone screen without overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(280, 600),
          incomes: testIncomes,
          expenses: testExpenses,
          budgets: testBudgets,
          healthScore: testHealth,
          suggestions: testSuggestions,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders on large accessibility font scale (1.5x) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(360, 800),
          textScaler: const TextScaler.linear(1.5),
          incomes: testIncomes,
          expenses: testExpenses,
          budgets: testBudgets,
          healthScore: testHealth,
          suggestions: testSuggestions,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
