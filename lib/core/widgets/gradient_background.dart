import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

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
        gradient: gradient ?? context.palette.backgroundGradient,
      ),
      child: useSafeArea ? SafeArea(child: content) : content,
    );
  }
}
