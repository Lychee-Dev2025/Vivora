import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/info_card.dart';

class TrendCard extends StatelessWidget {
  const TrendCard({
    super.key,
    required this.title,
    required this.value,
    required this.delta,
    this.positive = true,
  });

  final String title;
  final String value;
  final String delta;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor = positive
        ? AppColors.accentGreen
        : context.palette.danger;

    return InfoCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: deltaColor,
              ),
              const SizedBox(width: 4),
              Text(
                delta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
