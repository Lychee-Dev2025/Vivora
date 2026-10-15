import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/widgets/info_card.dart';

class ReportTile extends StatelessWidget {
  const ReportTile({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.trend,
    required this.onView,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String trend;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(summary, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(
                  trend,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.brand.withValues(alpha: 0.1),
            ),
            child: IconButton(
              onPressed: onView,
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: context.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
