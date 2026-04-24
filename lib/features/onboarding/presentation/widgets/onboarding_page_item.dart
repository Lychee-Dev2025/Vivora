import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_page_wrapper.dart';
import '../../data/onboarding_model.dart';

class OnboardingPageItem extends StatelessWidget {
  const OnboardingPageItem({super.key, required this.item});

  final OnboardingModel item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AnimatedPageWrapper(
            duration: const Duration(milliseconds: 650),
            beginOffset: const Offset(0.08, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x172D426A),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(item.image, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedPageWrapper(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 520),
          child: Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedPageWrapper(
          delay: const Duration(milliseconds: 180),
          duration: const Duration(milliseconds: 560),
          child: Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
