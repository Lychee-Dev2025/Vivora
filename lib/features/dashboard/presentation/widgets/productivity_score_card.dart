import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/info_card.dart';

class ProductivityScoreCard extends StatelessWidget {
  const ProductivityScoreCard({
    super.key,
    required this.score,
    this.level = 'Medium',
    this.feedback = 'Log your progress to see your productivity score.',
    this.onLogTap,
  });

  final String score;
  final String level;
  final String feedback;
  final VoidCallback? onLogTap;

  @override
  Widget build(BuildContext context) {
    final bool isInitial = score == '--';

    return InfoCard(
      gradient: isInitial
          ? context.palette.splashGradient
          : context.palette.highlightGradient,
      radius: 26,
      boxShadow: [
        BoxShadow(
          color: isInitial
              ? context.brand.withValues(alpha: 0.3)
              : const Color(0x4062D7B0),
          blurRadius: 30,
          spreadRadius: 2,
          offset: const Offset(0, 14),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Productivity Score',
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isInitial && level.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          level,
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      feedback,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.palette.textPrimary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                  color: context.palette.textPrimary.withValues(alpha: 0.05),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  // Keeps the number prominent but inside the circle at large
                  // font sizes ("100" at 1.5x would otherwise spill out).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      score,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onLogTap != null) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: onLogTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    isInitial
                        ? 'Calculate Today\'s Score'
                        : 'Update Today\'s Progress',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
