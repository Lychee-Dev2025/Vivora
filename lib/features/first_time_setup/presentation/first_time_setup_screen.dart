import 'package:flutter/material.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/gradient_background.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/personal_info_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/routine_profile_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/goals_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/preferences_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/setup_summary_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/welcome_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/progress_header.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/first_time_setup/data/services/user_profile_service.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  final PageController _pageController = PageController();
  final UserProfileService _profileService = UserProfileService();
  int _currentStep = 0;
  bool _isLoading = false;

  // Data state
  String _fullName = '';
  String _ageRange = '';
  String _academicLevel = '';
  String _institution = '';
  String _fieldOfStudy = '';

  String _wakeUpTime = '07:00 AM';
  String _sleepTime = '11:00 PM';
  String _averageStudyHours = '4';
  String _preferredStudyTime = 'Morning';
  String _currentScreenTimeEstimate = '5h';
  String _mainDailyChallenge = 'Procrastination';

  String _targetSleepHours = '8';
  String _targetStudyHours = '6';
  String _targetFocusHours = '4';
  String _targetScreenTimeLimit = '3h';
  String _productivityGoalType = 'Improve focus';

  bool _smartReminders = true;
  bool _motivationalTips = true;
  bool _dailySummary = true;
  bool _analyticsSuggestions = true;

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          fullName: _fullName,
          ageRange: _ageRange,
          academicLevel: _academicLevel,
          institution: _institution,
          fieldOfStudy: _fieldOfStudy,
          routineProfile: RoutineProfile(
            wakeUpTime: _wakeUpTime,
            sleepTime: _sleepTime,
            averageStudyHours: _averageStudyHours,
            preferredStudyTime: _preferredStudyTime,
            currentScreenTimeEstimate: _currentScreenTimeEstimate,
            mainDailyChallenge: _mainDailyChallenge,
          ),
          goals: UserGoals(
            targetSleepHours: _targetSleepHours,
            targetStudyHours: _targetStudyHours,
            targetFocusHours: _targetFocusHours,
            targetScreenTimeLimit: _targetScreenTimeLimit,
            productivityGoalType: _productivityGoalType,
          ),
          preferences: UserPreferences(
            smartReminders: _smartReminders,
            motivationalTips: _motivationalTips,
            dailySummary: _dailySummary,
            analyticsSuggestions: _analyticsSuggestions,
          ),
          setupCompleted: true,
          profileCompletedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await _profileService.saveUserProfile(profile);

        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.mainNavigation, (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, action: 'save your profile')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ProgressHeader(
                currentStep: _currentStep,
                totalSteps: 6,
                onBack: _currentStep > 0 ? _previousStep : null,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() => _currentStep = page);
                  },
                  children: [
                    WelcomeStep(onContinue: _nextStep),
                    PersonalInfoStep(
                      onContinue: (name, age, level, inst, field) {
                        _fullName = name;
                        _ageRange = age;
                        _academicLevel = level;
                        _institution = inst;
                        _fieldOfStudy = field;
                        _nextStep();
                      },
                    ),
                    RoutineProfileStep(
                      onContinue:
                          (wake, sleep, study, pref, screen, challenge) {
                            _wakeUpTime = wake;
                            _sleepTime = sleep;
                            _averageStudyHours = study;
                            _preferredStudyTime = pref;
                            _currentScreenTimeEstimate = screen;
                            _mainDailyChallenge = challenge;
                            _nextStep();
                          },
                    ),
                    GoalsStep(
                      onContinue: (sleep, study, focus, screen, type) {
                        _targetSleepHours = sleep;
                        _targetStudyHours = study;
                        _targetFocusHours = focus;
                        _targetScreenTimeLimit = screen;
                        _productivityGoalType = type;
                        _nextStep();
                      },
                    ),
                    PreferencesStep(
                      onContinue: (smart, tips, summary, suggestions) {
                        _smartReminders = smart;
                        _motivationalTips = tips;
                        _dailySummary = summary;
                        _analyticsSuggestions = suggestions;
                        _nextStep();
                      },
                    ),
                    SetupSummaryStep(
                      fullName: _fullName,
                      academicLevel: _academicLevel,
                      mainChallenge: _mainDailyChallenge,
                      productivityGoal: _productivityGoalType,
                      isLoading: _isLoading,
                      onEdit: (step) => _goToStep(step),
                      onFinish: _finishSetup,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
