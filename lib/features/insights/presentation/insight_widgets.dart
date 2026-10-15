import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../core/widgets/info_card.dart';
import '../services/recommendation_service.dart';

/// Rule-based recommendations with the evidence that triggered each one.
class RecommendationsCard extends StatelessWidget {
  const RecommendationsCard({
    super.key,
    required this.recommendations,
    this.loading = false,
  });

  final List<Recommendation> recommendations;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lightbulb_outline_rounded, color: context.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            RecommendationService.sourceLabel,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (loading && recommendations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (recommendations.isEmpty)
            Text(
              'No suggestions yet. They appear once Vivora has recorded your app usage, scores or focus sessions.',
              style: TextStyle(color: context.palette.textSecondary),
            )
          else
            for (final Recommendation r in recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(r.action),
                    const SizedBox(height: 2),
                    Text(
                      'Why: ${r.evidence}',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
