import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import '../../../../core/widgets/primary_button.dart';

class SetupSummaryStep extends StatelessWidget {
  final String fullName;
  final String academicLevel;
  final String mainChallenge;
  final String productivityGoal;
  final bool isLoading;
  final Function(int) onEdit;
  final VoidCallback onFinish;

  const SetupSummaryStep({
    super.key,
    required this.fullName,
    required this.academicLevel,
    required this.mainChallenge,
    required this.productivityGoal,
    required this.isLoading,
    required this.onEdit,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Ready to Start?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Here is a quick summary of your profile.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildSummaryCard(
            context,
            title: 'Personal Info',
            items: [
              {'label': 'Name', 'value': fullName},
              {'label': 'Level', 'value': academicLevel},
            ],
            onEdit: () => onEdit(1),
            delay: 200,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            context,
            title: 'Routine & Challenges',
            items: [
              {'label': 'Main Challenge', 'value': mainChallenge},
            ],
            onEdit: () => onEdit(2),
            delay: 300,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            context,
            title: 'Goals',
            items: [
              {'label': 'Focus Goal', 'value': productivityGoal},
            ],
            onEdit: () => onEdit(3),
            delay: 400,
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: PrimaryButton(
              label: 'Finish Setup',
              isLoading: isLoading,
              onPressed: onFinish,
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: Center(
              child: Text(
                'You can update these anytime in Settings.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required List<Map<String, String>> items,
    required VoidCallback onEdit,
    required int delay,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.palette.shadow.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: context.palette.shadow.withValues(alpha: 0.05),
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
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_note_rounded, color: context.brand),
                  onPressed: onEdit,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    Text(
                      item['value']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
