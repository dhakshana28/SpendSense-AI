import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_provider.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GoalProvider>().subscribe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = userProvider.user?.currency ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => goalProvider.subscribe(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _buildHeader(context, goalProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildOverallProgress(context, goalProvider, currency, isDark),
              const SizedBox(height: 20),
              ...goalProvider.goals.map((goal) => _buildGoalCard(context, goal, currency, isDark, goalProvider)),
              if (goalProvider.goals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text('No goals yet. Start saving!', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context, goalProvider, currency),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Goal'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GoalProvider goalProvider, String currency, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Savings Goals',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your progress',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildOverallProgress(BuildContext context, GoalProvider goalProvider, String currency, bool isDark) {
    final totalSaved = goalProvider.totalSavings;
    final totalTarget = goalProvider.totalTargets;
    final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.premiumGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Savings', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalSaved),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '$currency${value.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                    );
                  },
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: overallProgress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(overallProgress * 100).toStringAsFixed(0)}% of $currency${totalTarget.toStringAsFixed(0)} target',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: overallProgress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  '${(overallProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalModel goal, String currency, bool isDark, GoalProvider goalProvider) {
    final progress = goal.progress.clamp(0.0, 1.0);
    final remaining = goal.targetAmount - goal.savedAmount;
    final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
    final isCompleted = progress >= 1.0;
    final isUrgent = daysLeft <= 30 && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? AppTheme.secondaryGradient
            : isDark
                ? AppTheme.darkCardGradient
                : LinearGradient(
                    colors: [Colors.white, Colors.white.withValues(alpha: 0.95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF6C63FF).withValues(alpha: 0.08),
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
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isCompleted ? Colors.white : (isDark ? const Color(0xFF6C63FF) : const Color(0xFF6C63FF))).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showEditGoalDialog(context, goalProvider, goal, currency),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCompleted ? Colors.white : const Color(0xFF6C63FF)).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit, color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF6C63FF)), size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final confirmed = await _showDeleteConfirmation(context);
                      if (confirmed == true) {
                        await goalProvider.deleteGoal(goal.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Goal deleted'), backgroundColor: Color(0xFFFF4757)),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4757).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete, color: Color(0xFFFF4757), size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(
                        color: (isCompleted ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$currency${goal.targetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: TextStyle(
                        color: (isCompleted ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$currency${goal.savedAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF00D9A6), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        color: (isCompleted ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF8E8EA0))),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$currency${remaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isCompleted ? Colors.white : (remaining < 0 ? const Color(0xFFFF4757) : (isDark ? Colors.white : const Color(0xFF1A1A2E))),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE8E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? Colors.white : const Color(0xFF00D9A6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isCompleted ? Colors.white : (isDark ? const Color(0xFF6C63FF) : const Color(0xFF6C63FF))).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMM yyyy').format(goal.targetDate),
                      style: TextStyle(
                        color: isCompleted ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUrgent)
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: isCompleted ? Colors.white : const Color(0xFFFFB84D)),
                    const SizedBox(width: 4),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(
                        color: isCompleted ? Colors.white : const Color(0xFFFFB84D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (isCompleted)
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: isCompleted ? Colors.white : const Color(0xFFFFB84D)),
                    const SizedBox(width: 4),
                    Text(
                      'Reached!',
                      style: TextStyle(
                        color: isCompleted ? Colors.white : const Color(0xFFFFB84D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddGoalDialog(BuildContext context, GoalProvider goalProvider, String currency) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 180));

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
                  Text('Add Savings Goal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Goal Title', hintText: 'e.g., New Laptop'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a goal title';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Target Amount ($currency)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter target amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: savedController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Initial Savings ($currency)'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        setState(() => targetDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Target Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                      child: Text(DateFormat('dd MMM yyyy').format(targetDate)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: goalProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final goal = GoalModel(
                          id: '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? ''}',
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          title: titleController.text.trim(),
                          targetAmount: double.parse(targetController.text.trim()),
                          savedAmount: double.tryParse(savedController.text.trim()) ?? 0,
                          targetDate: targetDate,
                        );
                        try {
                          await goalProvider.addGoal(goal);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Goal added successfully!'), backgroundColor: Color(0xFF00D9A6)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add goal: ${e.toString()}'), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: goalProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Goal'),
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

  Future<void> _showEditGoalDialog(BuildContext context, GoalProvider goalProvider, GoalModel goal, String currency) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(text: goal.targetAmount.toString());
    final savedController = TextEditingController(text: goal.savedAmount.toString());
    DateTime selectedDate = goal.targetDate;

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
                  Text('Edit Goal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Goal Title', hintText: 'e.g., New Laptop'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a goal title';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Target Amount ($currency)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter target amount';
                      if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                      if (double.parse(value.trim()) <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: savedController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Saved Amount ($currency)'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Target Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                      child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: goalProvider.isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = goal.copyWith(
                          title: titleController.text.trim(),
                          targetAmount: double.parse(targetController.text.trim()),
                          savedAmount: double.tryParse(savedController.text.trim()) ?? goal.savedAmount,
                          targetDate: selectedDate,
                        );
                        try {
                          await goalProvider.updateGoal(updated);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Goal updated successfully!'), backgroundColor: Color(0xFF4DABF7)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update goal: ${e.toString()}'), backgroundColor: const Color(0xFFFF4757)),
                            );
                          }
                        }
                      },
                      child: goalProvider.isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Update Goal'),
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
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this savings goal?'),
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