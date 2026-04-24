import 'package:flutter/material.dart';
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
    bool isInitial = score == '--' || score == '0';

    return InfoCard(
      gradient: isInitial ? AppColors.splashGradient : AppColors.highlightGradient,
      radius: 26,
      boxShadow: [
        BoxShadow(
          color: isInitial 
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Productivity Score',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isInitial) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              level,
                              style: const TextStyle(
                                color: AppColors.darkText,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feedback,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.darkText,
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
                    color: AppColors.darkText.withValues(alpha: 0.1),
                    width: 2,
                  ),
                  color: AppColors.darkText.withValues(alpha: 0.05),
                ),
                child: Center(
                  child: Text(
                    score,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.darkText,
                      fontWeight: FontWeight.w800,
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    isInitial ? 'Calculate Today\'s Score' : 'Update Today\'s Progress',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
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
