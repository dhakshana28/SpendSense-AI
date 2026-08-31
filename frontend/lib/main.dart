import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'services/ai/gemini_service.dart';
import 'services/notification_service.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

import 'providers/auth_provider.dart';
import 'providers/income_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/savings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables first
  try {
    await dotenv.load(fileName: '.env');
    final apiKeyPresent = dotenv.env['GEMINI_API_KEY']?.isNotEmpty ?? false;
    debugPrint('.env loaded successfully');
    debugPrint('API key detected: $apiKeyPresent');
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore settings for better web connectivity
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  
  // Initialize Gemini service (reads from .env, no crash if missing)
  // NOTE: We do NOT send a test request here. Sending a test request with
  // empty data would trigger a cooldown on failure, which would cause the
  // app to fall back to Local AI. Gemini should only be tested when the
  // user actually uses a feature.
  try {
    await GeminiService.initialize();
    debugPrint('Gemini model initialized: ${GeminiService.currentModelName}');
  } catch (e) {
    debugPrint('Gemini AI initialization failed: $e');
  }
  
  runApp(SpendSenseApp(themeProvider: themeProvider));
}

class SpendSenseApp extends StatefulWidget {
  const SpendSenseApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  State<SpendSenseApp> createState() => _SpendSenseAppState();
}

class _SpendSenseAppState extends State<SpendSenseApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    if (!mounted) return;
    // Initialize Gemini service (reads from .env, no crash if missing)
    try {
      final aiProvider = context.read<AIProvider>();
      await aiProvider.initializeGemini();
    } catch (_) {
      // Silently continue - Gemini is optional
    }
    // Initialize local notifications
    await NotificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
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