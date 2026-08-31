import 'package:flutter/material.dart';

/// The four supported financial segments a user can select for their profile.
///
/// These are user-selectable financial personas — NOT sample users. The
/// authenticated user picks the segment that best matches their situation,
/// and the application personalizes insights, suggestions and AI context.
enum FinancialPersona {
  student(
    id: 'student',
    label: 'Student',
    description: 'Simple budgeting & savings',
    icon: Icons.school_outlined,
  ),
  workingProfessional(
    id: 'working_professional',
    label: 'Working Professional',
    description: 'Structured financial planning',
    icon: Icons.work_outline,
  ),
  freelancer(
    id: 'freelancer',
    label: 'Freelancer',
    description: 'Variable income management',
    icon: Icons.computer_outlined,
  ),
  familyIndividual(
    id: 'family_individual',
    label: 'Family / Individual',
    description: 'Household & personal planning',
    icon: Icons.home_outlined,
  );

  const FinancialPersona({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;

  /// All supported personas, in the order they should be displayed.
  static const List<FinancialPersona> all = [
    FinancialPersona.student,
    FinancialPersona.workingProfessional,
    FinancialPersona.freelancer,
    FinancialPersona.familyIndividual,
  ];

  /// Looks up a persona by its storage id (e.g. "freelancer").
  static FinancialPersona? fromId(String? id) {
    if (id == null) return null;
    for (final persona in all) {
      if (persona.id == id) return persona;
    }
    return null;
  }

  /// Segment-specific guidance appended to AI prompts so both Gemini and
  /// Local AI can tailor recommendations. Always uses the real user's data;
  /// this only shapes the framing, never fabricates facts.
  String get aiGuidance => switch (this) {
        FinancialPersona.student =>
          'The user is a student with limited or variable income. Focus on '
              'simple budgeting, daily expense tracking, small savings goals, '
              'food and transport spending, subscription awareness, and '
              'avoiding end-of-month overspending.',
        FinancialPersona.workingProfessional =>
          'The user is a working professional with a regular salary. Focus on '
              'monthly expense management, savings targets, an emergency fund, '
              'subscription management, financial health, spending '
              'predictions, and goal planning.',
        FinancialPersona.freelancer =>
          'The user is a freelancer with irregular, project-based income. '
              'Focus on variable-income budgeting, cash-flow planning, '
              'business vs personal expense tracking, saving during high-'
              'income months, planning for low-income months, and financial '
              'stability. Do NOT assume a fixed monthly salary.',
        FinancialPersona.familyIndividual =>
          'The user manages household or individual finances. Focus on '
              'household budgeting, category-wise expenses, bills and recurring '
              'payments, education/home/emergency savings, and long-term '
              'financial planning.',
      };
}
