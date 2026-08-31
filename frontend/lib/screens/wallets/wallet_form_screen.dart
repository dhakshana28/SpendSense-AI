import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/glass_card.dart';

class WalletFormScreen extends StatefulWidget {
  final WalletModel? wallet;

  const WalletFormScreen({super.key, this.wallet});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _uuid = const Uuid();

  String _selectedIcon = 'account_balance_wallet';
  String _selectedColor = '#6C63FF';
  bool _isEditing = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _walletIcons = [
    {'name': 'account_balance_wallet', 'icon': Icons.account_balance_wallet},
    {'name': 'account_balance', 'icon': Icons.account_balance},
    {'name': 'business', 'icon': Icons.business},
    {'name': 'credit_card', 'icon': Icons.credit_card},
    {'name': 'savings', 'icon': Icons.savings},
    {'name': 'wallet', 'icon': Icons.wallet},
    {'name': 'luggage', 'icon': Icons.luggage},
    {'name': 'family_restroom', 'icon': Icons.family_restroom},
    {'name': 'emergency', 'icon': Icons.emergency},
    {'name': 'person', 'icon': Icons.person},
    {'name': 'groups', 'icon': Icons.groups},
    {'name': 'home', 'icon': Icons.home},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'school', 'icon': Icons.school},
    {'name': 'flight', 'icon': Icons.flight},
    {'name': 'card_travel', 'icon': Icons.card_travel},
    {'name': 'weekend', 'icon': Icons.weekend},
  ];

  final List<String> _walletColors = [
    '#6C63FF', '#FF6584', '#00D9A6', '#FFB84D',
    '#4DABF7', '#845EF7', '#20C997', '#FF8A9E',
    '#F06595', '#5C7CFA', '#51CF66', '#FF922B',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _isEditing = true;
      _nameController.text = widget.wallet!.name;
      _descriptionController.text = widget.wallet!.description;
      _initialBalanceController.text = widget.wallet!.initialBalance.toString();
      _selectedIcon = widget.wallet!.icon;
      _selectedColor = widget.wallet!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Color _parseColor(String colorStr) {
    final hex = colorStr.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final walletProvider = context.read<WalletProvider>();
    if (!_isEditing && walletProvider.isDuplicateName(_nameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A wallet with this name already exists')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final initialBalance = double.tryParse(_initialBalanceController.text) ?? 0;

      if (_isEditing && widget.wallet != null) {
        final updated = widget.wallet!.copyWith(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          description: _descriptionController.text.trim(),
          lastUpdated: now,
        );
        await walletProvider.updateWallet(updated);
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final wallet = WalletModel(
          id: _uuid.v4(),
          userId: uid,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          initialBalance: initialBalance,
          currentBalance: initialBalance,
          description: _descriptionController.text.trim(),
          createdDate: now,
          lastUpdated: now,
        );
        await walletProvider.addWallet(wallet);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Wallet' : 'Create Wallet'),
        backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g., Personal Wallet',
                  prefixIcon: const Icon(Icons.wallet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a wallet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Daily expenses wallet',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Initial Balance
              if (!_isEditing)
                TextFormField(
                  controller: _initialBalanceController,
                  decoration: InputDecoration(
                    labelText: 'Initial Balance',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.monetization_on),
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return 'Please enter a valid amount';
                      }
                    }
                    return null;
                  },
                ),
              if (!_isEditing) const SizedBox(height: 24),

              // Icon Selection
              Text(
                'Choose Icon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _walletIcons.length,
                  itemBuilder: (context, index) {
                    final item = _walletIcons[index];
                    final isSelected = _selectedIcon == item['name'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = item['name']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _parseColor(_selectedColor).withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: _parseColor(_selectedColor), width: 2)
                              : null,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: isSelected ? _parseColor(_selectedColor) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Color Selection
              Text(
                'Choose Color',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _walletColors.map((colorStr) {
                  final color = _parseColor(colorStr);
                  final isSelected = _selectedColor == colorStr;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorStr),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Preview
              GlassCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseColor(_selectedColor).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _walletIcons.firstWhere(
                            (i) => i['name'] == _selectedIcon,
                            orElse: () => _walletIcons.first,
                          )['icon'] as IconData,
                          color: _parseColor(_selectedColor),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.isEmpty
                                  ? 'Wallet Name'
                                  : _nameController.text,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹ ${_initialBalanceController.text.isEmpty ? '0' : _initialBalanceController.text}',
                              style: TextStyle(
                                color: _parseColor(_selectedColor),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Wallet' : 'Create Wallet',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}