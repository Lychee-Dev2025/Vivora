import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import '../../../../core/widgets/primary_button.dart';

class PreferencesStep extends StatefulWidget {
  final Function(bool, bool, bool, bool) onContinue;

  const PreferencesStep({super.key, required this.onContinue});

  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  bool _smartReminders = true;
  bool _motivationalTips = true;
  bool _dailySummary = true;
  bool _analyticsSuggestions = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    child: Text(
                      'App Preferences',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.palette.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInDown(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'Customize how Vivora interacts with you.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildPreferenceTile(
                    title: 'Smart Reminders',
                    subtitle: 'Get notified when it’s time to focus or rest.',
                    value: _smartReminders,
                    icon: Icons.notifications_active_rounded,
                    onChanged: (val) => setState(() => _smartReminders = val),
                    delay: 200,
                  ),
                  _buildPreferenceTile(
                    title: 'Motivational Tips',
                    subtitle: 'Receive daily boosts to keep you going.',
                    value: _motivationalTips,
                    icon: Icons.lightbulb_rounded,
                    onChanged: (val) => setState(() => _motivationalTips = val),
                    delay: 300,
                  ),
                  _buildPreferenceTile(
                    title: 'Daily Summary',
                    subtitle: 'A quick wrap-up of your achievements.',
                    value: _dailySummary,
                    icon: Icons.assignment_rounded,
                    onChanged: (val) => setState(() => _dailySummary = val),
                    delay: 400,
                  ),
                  _buildPreferenceTile(
                    title: 'Analytics Suggestions',
                    subtitle: 'Get personalized advice based on your data.',
                    value: _analyticsSuggestions,
                    icon: Icons.auto_graph_rounded,
                    onChanged: (val) =>
                        setState(() => _analyticsSuggestions = val),
                    delay: 500,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: PrimaryButton(
              label: 'Review Setup',
              onPressed: () {
                widget.onContinue(
                  _smartReminders,
                  _motivationalTips,
                  _dailySummary,
                  _analyticsSuggestions,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required int delay,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.palette.shadow.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: context.palette.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.brand, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.brand,
            ),
          ],
        ),
      ),
    );
  }
}
