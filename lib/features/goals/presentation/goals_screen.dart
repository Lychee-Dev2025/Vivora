import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: GradientBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            Text(
              'Your Targets',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Track and adjust your daily habits to stay aligned.'),
            const SizedBox(height: 20),
            _GoalCard(
              title: 'Screen Time Goal',
              target: '< 4h 0m',
              current: '2h 15m',
              progress: 0.55,
              icon: Icons.phone_android_rounded,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 12),
            _GoalCard(
              title: 'Sleep Goal',
              target: '8h 0m',
              current: '7h 10m',
              progress: 0.85,
              icon: Icons.nightlight_round,
              color: AppColors.softPurple,
            ),
            const SizedBox(height: 12),
            _GoalCard(
              title: 'Study Goal',
              target: '3h 30m',
              current: '1h 20m',
              progress: 0.38,
              icon: Icons.auto_stories_rounded,
              color: AppColors.secondaryCyan,
            ),
            const SizedBox(height: 12),
            _GoalCard(
              title: 'Focus Goal',
              target: '2h 0m',
              current: '1h 50m',
              progress: 0.92,
              icon: Icons.center_focus_strong_rounded,
              color: AppColors.accentGreen,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.title,
    required this.target,
    required this.current,
    required this.progress,
    required this.icon,
    required this.color,
  });

  final String title;
  final String target;
  final String current;
  final double progress;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: AppColors.lightText,
                tooltip: 'Edit goal',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                current,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                'Target: $target',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.scaffoldBackground,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
