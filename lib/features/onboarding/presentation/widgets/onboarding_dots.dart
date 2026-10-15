import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.controller,
    required this.count,
  });

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SmoothPageIndicator(
      controller: controller,
      count: count,
      effect: ExpandingDotsEffect(
        dotHeight: 8,
        dotWidth: 8,
        expansionFactor: 3.5,
        spacing: 6,
        activeDotColor: context.brand,
        dotColor: context.brand.withValues(alpha: 0.22),
      ),
    );
  }
}
