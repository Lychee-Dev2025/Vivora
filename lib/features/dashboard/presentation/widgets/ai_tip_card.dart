import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/info_card.dart';

class AiTipCard extends StatelessWidget {
  const AiTipCard({super.key, required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.secondaryCyan.withValues(alpha: 0.14),
          AppColors.softPurple.withValues(alpha: 0.13),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Tip',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.darkText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
