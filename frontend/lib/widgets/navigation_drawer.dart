import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../app/theme/app_theme.dart';
import '../providers/auth_provider.dart' as app;
import '../providers/user_provider.dart';

class AppNavigationDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const AppNavigationDrawer({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final authProvider = context.watch<app.AuthProvider>();
    final firebaseUser = authProvider.firebaseUser;
    final userName = userProvider.user?.name ??
        firebaseUser?.displayName ??
        'User';
    final userEmail = userProvider.user?.email ?? firebaseUser?.email ?? '';
    final photoUrl =
        userProvider.user?.photoUrl ?? firebaseUser?.photoURL;

    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 34)
                      : null,
                ),
                const SizedBox(height: 14),
                // App Name + Logo row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SpendSense AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Smart Budgeting & Expense Management',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                // User Name
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(
                    context, 0, Icons.dashboard, 'Dashboard', isDark),
                _buildDrawerItem(
                    context, 1, Icons.account_balance_wallet, 'Wallet Dashboard', isDark),
                _buildDrawerItem(
                    context, 2, Icons.trending_up, 'Savings Analytics', isDark),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildDrawerItem(
                    context, 3, Icons.account_balance_wallet, 'Income', isDark),
                _buildDrawerItem(
                    context, 4, Icons.payments, 'Expenses', isDark),
                _buildDrawerItem(
                    context, 5, Icons.pie_chart, 'Budget', isDark),
                _buildDrawerItem(
                    context, 6, Icons.analytics, 'Reports', isDark),
                _buildDrawerItem(
                    context, 7, Icons.person, 'Profile', isDark),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildDrawerItem(
                    context, 8, Icons.auto_awesome, 'AI Dashboard', isDark),
                _buildDrawerItem(
                    context, 9, Icons.chat, 'AI Chat', isDark),
                _buildDrawerItem(
                    context, 10, Icons.lightbulb_outline, 'AI Insights', isDark),
                _buildDrawerItem(
                    context, 11, Icons.favorite, 'Financial Health', isDark),
              ],
            ),
          ),
          // Bottom Section - Logout
          const Divider(height: 1),
          _buildLogoutItem(context, isDark),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, int index, IconData icon, String label, bool isDark) {
    final isSelected = currentIndex == index;
    final color =
        isSelected ? const Color(0xFF6C63FF) : (isDark ? Colors.white70 : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {
          onItemSelected(index);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.logout, color: Color(0xFFFF4757), size: 24),
              const SizedBox(width: 16),
              const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFFF4757),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<app.AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFFF4757)),
            ),
          ),
        ],
      ),
    );
  }
}