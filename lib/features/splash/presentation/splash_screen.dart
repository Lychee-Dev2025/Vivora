import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _continuousController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _floatOffset;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Entrance animation controller (1.5 seconds)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Continuous animation controller (3 seconds, repeating)
    _continuousController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Entrance: Fade in
    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    // Entrance: Scale up
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Continuous: Floating motion
    _floatOffset = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _continuousController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Continuous: Glow pulsing
    _glowScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _continuousController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowOpacity =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 0.4),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.4, end: 0.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _continuousController,
            curve: Curves.easeInOutSine,
          ),
        );

    // Start animations
    _entranceController.forward().then((_) {
      if (mounted) {
        _continuousController.repeat(reverse: true);
      }
    });

    // Navigation timer (3 seconds total)
    _navigationTimer = Timer(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No user logged in, go to onboarding
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      } else {
        // User is logged in, check verification and setup
        if (user.emailVerified) {
          final profileService = UserProfileService();
          bool isSetupCompleted;
          try {
            isSetupCompleted = await profileService
                .isSetupCompleted(user.uid)
                .timeout(const Duration(seconds: 8));
          } catch (error) {
            // Offline with no cached profile: open the app rather than hang
            // on the splash screen; data screens show their own offline state.
            debugPrint('Setup check failed, continuing: $error');
            isSetupCompleted = true;
          }

          if (mounted) {
            if (isSetupCompleted) {
              Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.mainNavigation);
            } else {
              Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.firstTimeSetup);
            }
          }
        } else {
          // Email not verified, go to auth (auth screen usually handles the message)
          Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
        }
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _continuousController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: context.palette.splashGradient),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _entranceController,
              _continuousController,
            ]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing Glow behind the logo
                  Transform.scale(
                    scale: _glowScale.value,
                    child: Opacity(
                      opacity: (_glowOpacity.value * _logoFade.value).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.brand.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Logo with entrance and floating animations
                  Transform.translate(
                    offset: Offset(0, _floatOffset.value),
                    child: Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Image.asset(
                          AppAssets.logo,
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
