import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/widgets/animated_page_wrapper.dart';
import '../../data/onboarding_model.dart';

class OnboardingPageItem extends StatelessWidget {
  const OnboardingPageItem({super.key, required this.item});

  final OnboardingModel item;

  @override
  Widget build(BuildContext context) {
    // The image takes a share of the page height and the text below it can
    // scroll: on a short screen or with large fonts the text no longer pushes
    // past the bottom of the page.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double imageHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight * 0.55).clamp(120.0, 440.0)
            : 320.0;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: imageHeight,
                child: AnimatedPageWrapper(
                  duration: const Duration(milliseconds: 650),
                  beginOffset: const Offset(0.08, 0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: context.palette.shadow,
                          blurRadius: 24,
                          offset: const Offset(0, 12),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
