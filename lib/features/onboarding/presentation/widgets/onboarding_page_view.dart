import 'package:flutter/material.dart';

import '../../data/onboarding_model.dart';
import 'onboarding_page_item.dart';

class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({
    super.key,
    required this.controller,
    required this.items,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<OnboardingModel> items;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: items.length,
      onPageChanged: onPageChanged,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OnboardingPageItem(item: items[index]),
        );
      },
    );
  }
}
