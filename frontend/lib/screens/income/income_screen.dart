import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../models/income_model.dart';
import '../../providers/income_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase/firebase_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final List<IncomeModel> _selectedForDeletion = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<IncomeProvider>().subscribe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final incomeProvider = context.watch<IncomeProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = userProvider.user?.currency ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => incomeProvider.subscribe(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _buildHeader(context, incomeProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildQuickInfo(context, incomeProvider, currency, isDark),
              const SizedBox(height: 20),
              if (_selectedForDeletion.isNotEmpty)
                _buildBulkActions(context, incomeProvider, isDark),
              ...incomeProvider.incomeList.map((income) => _buildIncomeCard(
                context,
                income,
                incomeProvider,
                currency,
                isDark,
              )),
              if (incomeProvider.incomeList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text('No income records yet. Add your first income!', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeDialog(context, incomeProvider, currency),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Income'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, IncomeProvider incomeProvider, String currency, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your earnings',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildQuickInfo(BuildContext context, IncomeProvider incomeProvider, String currency, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Income', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${incomeProvider.totalIncome.toStringAsFixed(0)}',
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
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Month', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$currency${incomeProvider.monthlyIncome.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkActions(BuildContext context, IncomeProvider incomeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('${_selectedForDeletion.length} selected', style: TextStyle(color: const Color(0xFFFF4757), fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() => _selectedForDeletion.clear());
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              for (final income in _selectedForDeletion) {
                await incomeProvider.deleteIncome(income.id);
              }
              setState(() => _selectedForDeletion.clear());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incomes deleted'), backgroundColor: Color(0xFF00D9A6)),
                );
              }
            },
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(BuildContext context, IncomeModel income, IncomeProvider incomeProvider, String currency, bool isDark) {
    final categoryIcons = {
      'Salary': Icons.account_balance_wallet, 'Freelance': Icons.work,
      'Investment': Icons.trending_up, 'Business': Icons.business,
      'Other': Icons.more_horiz,
    };
    final categoryColors = {
      'Salary': const Color(0xFF00D9A6), 'Freelance': const Color(0xFF4DABF7),
      'Investment': const Color(0xFFFFB84D), 'Business': const Color(0xFF6C63FF),
      'Other': const Color(0xFF8E8EA0),
    };

    final icon = categoryIcons[income.category] ?? Icons.account_balance_wallet;
    final color = categoryColors[income.category] ?? const Color(0xFF8E8EA0);
    final isSelected = _selectedForDeletion.contains(income);

    return Slidable(
      key: ValueKey(income.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.7,
        children: [
          SlidableAction(
            onPressed: (_) async {
              await _showEditIncomeDialog(context, incomeProvider, income, currency);
            },
            backgroundColor: const Color(0xFF4DABF7),
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) async {
              final confirmed = await _showDeleteConfirmation(context);
              if (confirmed == true) {
                await incomeProvider.deleteIncome(income.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Income deleted'), backgroundColor: Color(0xFFFF4757)),
                  );
                }
              }
            },
            backgroundColor: const Color(0xFFFF4757),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () {
            setState(() {
              if (isSelected) {
                _selectedForDeletion.remove(income);
              } else {
                _selectedForDeletion.add(income);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF4757).withValues(alpha: 0.1) : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? const Color(0xFFFF4757).withValues(alpha: 0.3) : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        income.category,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        income.description.isNotEmpty ? income.description : 'No description',
                        style: Theme.of(context).textTheme.bodySmall,
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
                      '+$currency${income.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: const Color(0xFF00D9A6),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(income.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    Text(
                      DateFormat('h:mm a').format(income.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddIncomeDialog(BuildContext context, IncomeProvider incomeProvider, String currency) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController(text: 'Salary');
    final sourceController = TextEditingController(text: 'Monthly Pay');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

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
                  Text('Add Income', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', hintText: 'Enter amount', prefixText: '₹ '),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter an amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Salary, Freelance'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a category';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: sourceController,
                    decoration: const InputDecoration(labelText: 'Source', hintText: 'e.g. Monthly Pay, Project'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a source';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'What was this income for?'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = DateTime(
                                picked.year, picked.month, picked.day,
                                selectedTime.hour, selectedTime.minute,
                              ));
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setState(() {
                                selectedTime = picked;
                                selectedDate = DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  picked.hour, picked.minute,
                                );
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.access_time, size: 20)),
                            child: Text(selectedTime.format(context)),
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
                      onPressed: incomeProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final income = IncomeModel(
                          id: '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? ''}',
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          amount: double.parse(amountController.text.trim()),
                          category: categoryController.text.trim(),
                          source: sourceController.text.trim(),
                          description: descriptionController.text.trim(),
                          date: selectedDate,
                          createdAt: DateTime.now(),
                        );
                        try {
                          await incomeProvider.addIncome(income);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Income added successfully!'), backgroundColor: Color(0xFF00D9A6)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(FirebaseService.getFriendlyError(e)), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: incomeProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Income'),
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

  Future<void> _showEditIncomeDialog(BuildContext context, IncomeProvider incomeProvider, IncomeModel income, String currency) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: income.amount.toString());
    final descriptionController = TextEditingController(text: income.description);
    final categoryController = TextEditingController(text: income.category);
    final sourceController = TextEditingController(text: income.source);
    DateTime selectedDate = income.date;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(income.date);

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
                  Text('Edit Income', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter an amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Salary, Freelance'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a category';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: sourceController,
                    decoration: const InputDecoration(labelText: 'Source', hintText: 'e.g. Monthly Pay, Project'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a source';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = DateTime(
                                picked.year, picked.month, picked.day,
                                selectedTime.hour, selectedTime.minute,
                              ));
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setState(() {
                                selectedTime = picked;
                                selectedDate = DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  picked.hour, picked.minute,
                                );
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.access_time, size: 20)),
                            child: Text(selectedTime.format(context)),
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
                      onPressed: incomeProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = income.copyWith(
                          amount: double.parse(amountController.text.trim()),
                          category: categoryController.text.trim(),
                          source: sourceController.text.trim(),
                          description: descriptionController.text.trim(),
                          date: selectedDate,
                        );
                        try {
                          await incomeProvider.updateIncome(updated);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Income updated successfully!'), backgroundColor: Color(0xFF4DABF7)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(FirebaseService.getFriendlyError(e)), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: incomeProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Update Income'),
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
        title: const Text('Delete Income'),
        content: const Text('Are you sure you want to delete this income record?'),
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