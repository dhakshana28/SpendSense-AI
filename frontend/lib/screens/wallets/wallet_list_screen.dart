import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/glass_card.dart';
import 'wallet_form_screen.dart';
import 'wallet_detail_screen.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().subscribe();
    });
  }

  IconData _getIcon(String iconName) {
    const iconMap = {
      'account_balance_wallet': Icons.account_balance_wallet,
      'account_balance': Icons.account_balance,
      'business': Icons.business,
      'card_giftcard': Icons.card_giftcard,
      'flight': Icons.flight,
      'emergency': Icons.emergency,
      'people': Icons.people,
      'person': Icons.person,
      'savings': Icons.savings,
      'wallet': Icons.wallet,
      'payments': Icons.payments,
      'credit_card': Icons.credit_card,
    };
    return iconMap[iconName] ?? Icons.account_balance_wallet;
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        final hex = colorStr.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6C63FF);
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallets = walletProvider.wallets;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showWalletForm(context),
          ),
        ],
      ),
      body: wallets.isEmpty
          ? _buildEmptyState(context, isDark)
          : RefreshIndicator(
              onRefresh: () async => walletProvider.subscribe(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: wallets.length,
                itemBuilder: (context, index) =>
                    _buildWalletCard(context, wallets[index], isDark),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: isDark ? Colors.white24 : const Color(0xFF8E8EA0),
          ),
          const SizedBox(height: 16),
          Text(
            'No Wallets Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white60 : const Color(0xFF8E8EA0),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a wallet to track your finances',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white38 : const Color(0xFFB0B0C0),
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showWalletForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WalletModel wallet, bool isDark) {
    final color = _parseColor(wallet.color);
    final balanceFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _openWalletDetail(context, wallet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIcon(wallet.icon),
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wallet.description.isNotEmpty
                          ? wallet.description
                          : 'No description',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white38 : const Color(0xFF8E8EA0),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceFormat.format(wallet.currentBalance),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Initial: ${balanceFormat.format(wallet.initialBalance)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : const Color(0xFF8E8EA0),
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWalletForm(BuildContext context, {WalletModel? wallet}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletFormScreen(wallet: wallet),
      ),
    );
  }

  void _openWalletDetail(BuildContext context, WalletModel wallet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletDetailScreen(wallet: wallet),
      ),
    );
  }
}