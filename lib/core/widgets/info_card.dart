import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
    this.radius = 22,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double radius;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.cardBackground : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            boxShadow ??
            const <BoxShadow>[
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 24,
                spreadRadius: 0,
                offset: Offset(0, 10),
              ),
            ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
