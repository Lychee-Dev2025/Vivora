import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'primary_button.dart';

class ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Map<String, String>> quickStats;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.title,
    required this.description,
    required this.quickStats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: quickStats.map((stat) {
              // Each stat gets an equal share and may wrap, so a long value
              // such as "Needs Improvement" cannot overflow the row.
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['value'] ?? '',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.brand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['label'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'View Details', onPressed: onTap),
        ],
      ),
    );
  }
}
