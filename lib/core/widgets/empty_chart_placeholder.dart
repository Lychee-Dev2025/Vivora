import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

class EmptyChartPlaceholder extends StatelessWidget {
  const EmptyChartPlaceholder({
    super.key,
    required this.label,
    this.height = 130,
  });

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    const List<double> bars = <double>[0.25, 0.5, 0.35, 0.74, 0.62, 0.81, 0.56];

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.palette.surfaceMuted,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.asMap().entries.map((MapEntry<int, double> entry) {
                final int index = entry.key;
                final double value = entry.value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: value),
                      duration: Duration(milliseconds: 600 + (index * 120)),
                      curve: Curves.easeOutCubic,
                      builder:
                          (
                            BuildContext context,
                            double animateValue,
                            Widget? child,
                          ) {
                            return FractionallySizedBox(
                              heightFactor: animateValue,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: context.palette.highlightGradient,
                                ),
                              ),
                            );
                          },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
