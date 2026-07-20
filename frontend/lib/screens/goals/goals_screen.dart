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
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(context, goalProvider, currency, isDark),
              const SizedBox(height: 20),
              _buildOverallProgress(context, goalProvider, currency, isDark),
              const SizedBox(height: 20),
              ...goalProvider.goals.map((goal) => _buildGoalCard(context, goal, currency, isDark)),
              if (goalProvider.goals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text('No goals yet. Start saving!', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context, goalProvider, currency),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Goal'),
        backgroundColor: Theme.of(context).primaryColor,
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

  Widget _buildGoalCard(BuildContext context, GoalModel goal, String currency, bool isDark) {
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
                      DateFormat('MMM d, yyyy').format(goal.targetDate),
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
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 180));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Savings Goal', style: Theme.of(context).textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Goal Title', hintText: 'e.g., New Laptop'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Target Amount ($currency)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Initial Savings ($currency)'),
                ),
                const SizedBox(height: 12),
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
                    decoration: const InputDecoration(labelText: 'Target Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(targetDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || targetController.text.isEmpty) return;
                final goal = GoalModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  title: titleController.text,
                  targetAmount: double.parse(targetController.text),
                  savedAmount: double.parse(savedController.text.isNotEmpty ? savedController.text : '0'),
                  targetDate: targetDate,
                );
                await goalProvider.addGoal(goal);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}