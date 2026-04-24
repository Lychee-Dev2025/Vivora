import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../data/onboarding_model.dart';
import 'widgets/onboarding_dots.dart';
import 'widgets/onboarding_page_view.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final List<OnboardingModel> _items = const <OnboardingModel>[
    OnboardingModel(
      image: AppAssets.onboarding1,
      title: 'Move Forward With Smarter Habits',
      subtitle:
          'Track your daily routine, understand your patterns, and build better habits with intelligent insights designed for student life.',
    ),
    OnboardingModel(
      image: AppAssets.onboarding2,
      title: 'Balance Sleep, Screen Time, and Growth',
      subtitle:
          'Monitor your sleep, phone usage, and productivity trends in one place so you can stay focused without losing balance.',
    ),
    OnboardingModel(
      image: AppAssets.onboarding3,
      title: 'Turn Daily Data Into Real Progress',
      subtitle:
          'Get meaningful reports, smart recommendations, and a clear view of your day to improve focus, consistency, and performance.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
  }

  Future<void> _handleNext() async {
    if (_currentIndex == _items.length - 1) {
      _goToAuth();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentIndex == _items.length - 1;

    return Scaffold(
      body: GradientBackground(
        gradient: AppColors.onboardingGradient,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: SecondaryButton(label: 'Skip', onPressed: _goToAuth),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: OnboardingPageView(
                controller: _pageController,
                items: _items,
                onPageChanged: (int index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                OnboardingDots(
                  controller: _pageController,
                  count: _items.length,
                ),
                const Spacer(),
                SizedBox(
                  width: 170,
                  child: PrimaryButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onPressed: _handleNext,
                    icon: isLast
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
