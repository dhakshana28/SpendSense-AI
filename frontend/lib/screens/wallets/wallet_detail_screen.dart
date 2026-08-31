import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/glass_card.dart';
import 'wallet_form_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final WalletModel wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  IconData _getWalletIcon(String iconName) {
    const iconMap = {
      'account_balance_wallet': Icons.account_balance_wallet,
      'account_balance': Icons.account_balance,
      'business': Icons.business,
      'credit_card': Icons.credit_card,
      'savings': Icons.savings,
      'wallet': Icons.wallet,
      'luggage': Icons.luggage,
      'family_restroom': Icons.family_restroom,
      'emergency': Icons.emergency,
      'person': Icons.person,
      'groups': Icons.groups,
      'home': Icons.home,
      'work': Icons.work,
      'school': Icons.school,
      'flight': Icons.flight,
      'card_travel': Icons.card_travel,
    };
    return iconMap[iconName] ?? Icons.account_balance_wallet;
  }

  void _deleteWallet() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text('Are you sure you want to delete "${widget.wallet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<WalletProvider>().deleteWallet(widget.wallet.id);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting wallet: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallet = walletProvider.getWalletById(widget.wallet.id) ?? widget.wallet;
    final icon = _getWalletIcon(wallet.icon);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = walletProvider.getWalletTransactions(wallet.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletFormScreen(wallet: wallet),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteWallet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            GlassCard(
              gradient: AppTheme.primaryGradient,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${wallet.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        wallet.currentBalance >= wallet.initialBalance
                            ? '▲ Growing'
                            : '▼ Declining',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Wallet Info
            GlassCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Name', wallet.name, isDark),
                    _buildInfoRow(context, 'Initial Balance', '₹${wallet.initialBalance.toStringAsFixed(2)}', isDark),
                    _buildInfoRow(context, 'Current Balance', '₹${wallet.currentBalance.toStringAsFixed(2)}', isDark),
                    if (wallet.description.isNotEmpty)
                      _buildInfoRow(context, 'Description', wallet.description, isDark),
                    _buildInfoRow(context, 'Created', DateFormat('MMM d, yyyy').format(wallet.createdDate), isDark),
                    _buildInfoRow(context, 'Last Updated', DateFormat('MMM d, yyyy - h:mm a').format(wallet.lastUpdated), isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Transactions Section
            Text(
              'Transactions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (transactions.isEmpty)
              GlassCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add income or expenses to this wallet',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...transactions.take(20).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (t.type == 'income'
                                    ? const Color(0xFF00D9A6)
                                    : const Color(0xFFFF6584))
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            t.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                            color: t.type == 'income' ? const Color(0xFF00D9A6) : const Color(0xFFFF6584),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description.isNotEmpty ? t.description : t.category,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, h:mm a').format(t.date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${t.type == 'income' ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: t.type == 'income'
                                ? const Color(0xFF00D9A6)
                                : const Color(0xFFFF6584),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF8E8EA0),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}