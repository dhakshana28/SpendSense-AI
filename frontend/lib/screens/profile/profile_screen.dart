import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadCurrentUser();
    });
  }

  Future<void> _editProfile() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final name = TextEditingController(text: user.name);
    final income = TextEditingController(text: user.monthlyIncome.toString());
    final budget = TextEditingController(text: user.monthlyBudget.toString());
    var currency = user.currency;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: income,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly income'),
            ),
            TextField(
              controller: budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly budget'),
            ),
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const ['₹', '\$', '€', '£']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) => setDialogState(() => currency = value ?? currency),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final parsedIncome = double.tryParse(income.text) ?? 0;
              final parsedBudget = double.tryParse(budget.text) ?? 0;
              if (name.text.trim().isEmpty || parsedIncome < 0 || parsedBudget < 0) return;
              try {
                await context.read<UserProvider>().updateProfile(
                  name: name.text,
                  currency: currency,
                  monthlyIncome: parsedIncome,
                  monthlyBudget: parsedBudget,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } on FirebaseException catch (error) {
                debugPrint('EditProfile FirebaseException: ${error.message}');
                if (dialogContext.mounted) _message(error.message ?? 'Unable to save profile.');
              } catch (error, stackTrace) {
                debugPrint('EditProfile unexpected error: $error');
                FlutterError.reportError(FlutterErrorDetails(
                  exception: error,
                  stack: stackTrace,
                  context: ErrorDescription('In _editProfile'),
                ));
                if (dialogContext.mounted) _message('An unexpected error occurred: $error');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    income.dispose();
    budget.dispose();
    if (saved == true && mounted) _message('Profile updated.');
  }

  Future<void> _resetPassword() async {
    final email = TextEditingController(
      text: context.read<UserProvider>().user?.email ??
          FirebaseAuth.instance.currentUser?.email ??
          '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      email.dispose();
      return;
    }
    final address = email.text.trim();
    email.dispose();
    if (!address.contains('@')) {
      _message('Enter a valid email address.');
      return;
    }
    try {
      await context.read<AuthProvider>().resetPassword(address);
      if (mounted) _message('Password reset link sent to $address.');
    } on FirebaseAuthException catch (error) {
      debugPrint('Profile resetPassword FirebaseAuthException [${error.code}]: ${error.message}');
      if (mounted) _message(FirebaseService.getFriendlyErrorMessage(error));
    } catch (error, stackTrace) {
      debugPrint('Profile resetPassword unexpected error: $error');
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In _resetPassword'),
      ));
      if (mounted) _message('Unable to send reset email: $error');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      context.read<UserProvider>().clear();
      context.read<IncomeProvider>().clear();
      context.read<ExpenseProvider>().clear();
      context.read<BudgetProvider>().clear();
      context.read<GoalProvider>().clear();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    } on FirebaseException catch (error) {
      debugPrint('Logout FirebaseException: ${error.message}');
      if (mounted) _message(error.message ?? 'Unable to logout. Please retry.');
    } catch (error, stackTrace) {
      debugPrint('Logout unexpected error: $error');
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In _logout'),
      ));
      if (mounted) _message('An unexpected error occurred during logout: $error');
    }
  }

  Future<void> _pickImage() async {
    try {
      await context.read<UserProvider>().pickAndUploadProfileImage();
      if (mounted && context.read<UserProvider>().error == null) {
        _message('Profile image updated.');
      }
    } on FirebaseException catch (error) {
      debugPrint('PickImage FirebaseException: ${error.message}');
      if (mounted) _message(error.message ?? 'Unable to upload image.');
    } catch (error, stackTrace) {
      debugPrint('PickImage unexpected error: $error');
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In _pickImage'),
      ));
      if (mounted) _message('Unable to upload image: $error');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final profile = context.watch<UserProvider>();
    final user = profile.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: user?.photoUrl?.isNotEmpty == true
                                  ? NetworkImage(user!.photoUrl!)
                                  : null,
                              child: user?.photoUrl?.isNotEmpty == true
                                  ? null
                                  : const Icon(Icons.person, size: 32),
                            ),
                            IconButton(
                              onPressed: profile.isLoading ? null : _pickImage,
                              icon: const Icon(Icons.camera_alt),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.name.isNotEmpty == true ? user!.name : 'Profile',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(user?.email ?? ''),
                        TextButton(onPressed: _editProfile, child: const Text('Edit Profile')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: theme.themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (value) {
                      if (value != null) context.read<ThemeProvider>().setThemeMode(value);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('Currency'),
                  subtitle: Text(user?.currency ?? '₹'),
                  onTap: _editProfile,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  value: profile.notificationsEnabled,
                  onChanged: profile.setNotificationsEnabled,
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Reset Password'),
                  onTap: _resetPassword,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'SpendSense AI',
                    applicationVersion: '1.0.0',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => _message('Privacy Policy will be available here.'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  onTap: () => _message('Terms & Conditions will be available here.'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}
