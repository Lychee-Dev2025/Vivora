import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/gradient_background.dart';
import 'widgets/auth_form.dart';
import 'widgets/auth_header.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;

  void _toggleMode(bool loginMode) {
    if (_isLogin == loginMode) {
      return;
    }
    setState(() {
      _isLogin = loginMode;
    });
  }

  Future<void> _handleSuccessfulAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileService = UserProfileService();
    final isSetupCompleted = await profileService.isSetupCompleted(user.uid);

    if (mounted) {
      if (isSetupCompleted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.mainNavigation,
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.firstTimeSetup,
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        gradient: AppColors.onboardingGradient,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                const AnimatedPageWrapper(
                  delay: Duration(milliseconds: 40),
                  child: AuthHeader(),
                ),
                const SizedBox(height: 24),
                AnimatedPageWrapper(
                  delay: const Duration(milliseconds: 120),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: AppColors.shadowColor,
                          blurRadius: 26,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        _AuthModeToggle(
                          isLogin: _isLogin,
                          onChanged: _toggleMode,
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: AuthForm(
                            key: ValueKey<bool>(_isLogin),
                            isLogin: _isLogin,
                            onSuccess: _handleSuccessfulAuth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppColors.buttonGradient,
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(true),
                  child: Center(
                    child: Text(
                      'Login',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isLogin ? AppColors.white : AppColors.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(false),
                  child: Center(
                    child: Text(
                      'Sign Up',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isLogin ? AppColors.darkText : AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
