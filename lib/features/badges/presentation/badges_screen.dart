import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: GradientBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            Text(
              'Achievements',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Unlock milestones as you build better habits.'),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.85,
              children: <Widget>[
                const _BadgeCard(
                  title: '7 Day Streak Master',
                  icon: Icons.local_fire_department_rounded,
                  unlocked: true,
                  color: Colors.orangeAccent,
                ),
                const _BadgeCard(
                  title: 'Focus King',
                  icon: Icons.star_rounded,
                  unlocked: true,
                  color: AppColors.primaryBlue,
                ),
                const _BadgeCard(
                  title: 'Early Sleeper',
                  icon: Icons.bedtime_rounded,
                  unlocked: true,
                  color: AppColors.softPurple,
                ),
                const _BadgeCard(
                  title: 'Digital Detox Day',
                  icon: Icons.phonelink_erase_rounded,
                  unlocked: false,
                ),
                const _BadgeCard(
                  title: 'Productivity Pro',
                  icon: Icons.workspace_premium_rounded,
                  unlocked: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.title,
    required this.icon,
    this.unlocked = false,
    this.color = AppColors.lightText,
  });

  final String title;
  final IconData icon;
  final bool unlocked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = unlocked
        ? color
        : AppColors.lightText.withValues(alpha: 0.3);

    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 38, color: effectiveColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            unlocked ? 'Unlocked' : 'Locked',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: unlocked ? AppColors.accentGreen : AppColors.lightText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
