import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/app_colors.dart';
import 'package:vivora/core/widgets/gradient_background.dart';
import 'package:vivora/core/widgets/primary_button.dart';
import 'package:vivora/features/first_time_setup/data/services/user_profile_service.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_score_service.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_repository.dart';

class DailyProductivityEntryScreen extends StatefulWidget {
  const DailyProductivityEntryScreen({super.key});

  @override
  State<DailyProductivityEntryScreen> createState() => _DailyProductivityEntryScreenState();
}

class _DailyProductivityEntryScreenState extends State<DailyProductivityEntryScreen> {
  final _scoreService = ProductivityScoreService();
  final _repository = ProductivityRepository();
  final _profileService = UserProfileService();
  
  bool _isLoading = false;

  // Input State
  double _sleepHours = 7.0;
  double _studyHours = 4.0;
  double _focusHours = 3.0;
  double _screenTime = 5.0;
  double _distractionLevel = 0.3; // Low to High (0-1)
  double _consistency = 80.0; // 0-100
  double _activity = 70.0; // 0-100

  Future<void> _saveEntry() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profile = await _profileService.getUserProfile(user.uid);
      if (profile == null) {
        throw Exception("Profile not found. Please complete setup first.");
      }

      final log = DailyProductivityLog(
        date: DateTime.now(),
        actualSleepHours: _sleepHours,
        actualStudyHours: _studyHours,
        actualFocusHours: _focusHours,
        actualScreenTimeHours: _screenTime,
        distractionLevel: _distractionLevel,
        consistencyScore: _consistency,
        activityScore: _activity,
      );

      final result = _scoreService.calculateScore(log: log, profile: profile);

      await _repository.saveDailyLog(
        uid: user.uid,
        log: log,
        result: result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Productivity log saved successfully!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.of(context).pop(true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Today\'s Progress'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                child: const Text(
                  'How was your day?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: const Text(
                  'Enter your metrics to calculate your daily score.',
                  style: TextStyle(color: AppColors.lightText),
                ),
              ),
              const SizedBox(height: 30),
              
              _buildSliderCard(
                title: 'Sleep Duration',
                value: _sleepHours,
                suffix: 'hrs',
                icon: Icons.nightlight_round,
                min: 0, max: 12, divisions: 24,
                onChanged: (val) => setState(() => _sleepHours = val),
                color: AppColors.primaryBlue,
              ),
              
              _buildSliderCard(
                title: 'Study Time',
                value: _studyHours,
                suffix: 'hrs',
                icon: Icons.menu_book_rounded,
                min: 0, max: 16, divisions: 32,
                onChanged: (val) => setState(() => _studyHours = val),
                color: AppColors.softPurple,
              ),

              _buildSliderCard(
                title: 'Deep Focus Time',
                value: _focusHours,
                suffix: 'hrs',
                icon: Icons.timer_rounded,
                min: 0, max: 12, divisions: 24,
                onChanged: (val) => setState(() => _focusHours = val),
                color: AppColors.accentGreen,
              ),

              _buildSliderCard(
                title: 'Screen Time',
                value: _screenTime,
                suffix: 'hrs',
                icon: Icons.phone_iphone_rounded,
                min: 0, max: 18, divisions: 36,
                onChanged: (val) => setState(() => _screenTime = val),
                color: Colors.orange,
              ),

              _buildSliderCard(
                title: 'Consistency Level',
                value: _consistency,
                suffix: '%',
                icon: Icons.repeat_rounded,
                min: 0, max: 100, divisions: 20,
                onChanged: (val) => setState(() => _consistency = val),
                color: AppColors.secondaryCyan,
              ),

              _buildSliderCard(
                title: 'Activity Score',
                value: _activity,
                suffix: '%',
                icon: Icons.directions_run_rounded,
                min: 0, max: 100, divisions: 20,
                onChanged: (val) => setState(() => _activity = val),
                color: Colors.pinkAccent,
              ),

              const SizedBox(height: 20),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: PrimaryButton(
                  label: 'Calculate & Save Score',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? () {} : _saveEntry,
                  icon: Icons.calculate_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required double value,
    required String suffix,
    required IconData icon,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.shadowColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${value.toStringAsFixed(1)}$suffix',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.1),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
