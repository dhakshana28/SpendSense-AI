import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

import 'providers/auth_provider.dart';
import 'providers/income_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore settings for better web connectivity
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false, // Disable persistence on web to avoid offline issues
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  runApp(SpendSenseApp(themeProvider: themeProvider));
}

class SpendSenseApp extends StatelessWidget {
  const SpendSenseApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SpendSense AI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.themeMode,
          initialRoute: AppRoutes.login,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}