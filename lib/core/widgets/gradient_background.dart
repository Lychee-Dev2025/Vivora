import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.useSafeArea = true,
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.onboardingGradient,
      ),
      child: useSafeArea ? SafeArea(child: content) : content,
    );
  }
}
