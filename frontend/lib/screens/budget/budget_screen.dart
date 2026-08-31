import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/user_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BudgetProvider>().subscribe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = userProvider.user?.currency ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => budgetProvider.subscribe(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _buildHeader(context, budgetProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildSummaryCards(context, budgetProvider, currency, isDark),
              const SizedBox(height: 20),
              ...budgetProvider.budgets.map((budget) => _buildBudgetCard(context, budget, currency, isDark, budgetProvider)),
              if (budgetProvider.budgets.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text('No budgets set. Create your first budget!', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context, budgetProvider, currency),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Budget'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BudgetProvider budgetProvider, String currency, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your spending limits',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BudgetProvider budgetProvider, String currency, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalBudget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Spent', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${budgetProvider.totalRemaining.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context, BudgetModel budget, String currency, bool isDark, BudgetProvider budgetProvider) {
    final progress = (budget.spentAmount / budget.budgetAmount).clamp(0.0, 1.0);
    final remaining = budget.budgetAmount - budget.spentAmount;
    final isExceeded = remaining < 0;
    final progressColor = isExceeded
        ? const Color(0xFFFF4757)
        : progress > 0.8
            ? const Color(0xFFFFB84D)
            : const Color(0xFF00D9A6);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkCardGradient : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isExceeded ? const Color(0xFFFF4757).withValues(alpha: 0.3) : const Color(0xFF6C63FF).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.category,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _showEditBudgetDialog(context, budgetProvider, budget, currency),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final confirmed = await _showDeleteConfirmation(context);
                      if (confirmed == true) {
                        await budgetProvider.deleteBudget(budget.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Budget deleted'), backgroundColor: Color(0xFFFF4757)),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Text(
                      '$currency${budget.budgetAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Spent', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Text(
                      '$currency${budget.spentAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Remaining', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  Text(
                    '$currency${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isExceeded ? const Color(0xFFFF4757) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isExceeded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4757), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: You have exceeded your budget!',
                      style: TextStyle(color: Color(0xFFFF4757), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (budget.startDate != budget.endDate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.white.withValues(alpha: 0.6), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd MMM').format(budget.startDate)} - ${DateFormat('dd MMM yyyy').format(budget.endDate)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddBudgetDialog(BuildContext context, BudgetProvider budgetProvider, String currency) async {
    final formKey = GlobalKey<FormState>();
    final categoryController = TextEditingController();
    final budgetAmountController = TextEditingController();
    final spentAmountController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Add Budget', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g., Food, Transport'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a category';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: budgetAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Budget Amount ($currency)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter budget amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: spentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Already Spent ($currency)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => startDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => endDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.date_range, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(endDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: budgetProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final budget = BudgetModel(
                          id: '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? ''}',
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          category: categoryController.text.trim(),
                          budgetAmount: double.parse(budgetAmountController.text.trim()),
                          spentAmount: double.tryParse(spentAmountController.text.trim()) ?? 0,
                          startDate: startDate,
                          endDate: endDate,
                        );
                        try {
                          await budgetProvider.addBudget(budget);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Budget added successfully!'), backgroundColor: Color(0xFF00D9A6)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add budget: ${e.toString()}'), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: budgetProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Budget'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditBudgetDialog(BuildContext context, BudgetProvider budgetProvider, BudgetModel budget, String currency) async {
    final formKey = GlobalKey<FormState>();
    final categoryController = TextEditingController(text: budget.category);
    final budgetAmountController = TextEditingController(text: budget.budgetAmount.toString());
    final spentAmountController = TextEditingController(text: budget.spentAmount.toString());
    DateTime startDate = budget.startDate;
    DateTime endDate = budget.endDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Edit Budget', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g., Food, Transport'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a category';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: budgetAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Budget Amount ($currency)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter budget amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: spentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Spent Amount ($currency)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => startDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => endDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.date_range, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(endDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: budgetProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = budget.copyWith(
                          category: categoryController.text.trim(),
                          budgetAmount: double.parse(budgetAmountController.text.trim()),
                          spentAmount: double.tryParse(spentAmountController.text.trim()) ?? budget.spentAmount,
                          startDate: startDate,
                          endDate: endDate,
                        );
                        try {
                          await budgetProvider.updateBudget(updated);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Budget updated successfully!'), backgroundColor: Color(0xFF4DABF7)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update budget: ${e.toString()}'), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: budgetProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Update Budget'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}