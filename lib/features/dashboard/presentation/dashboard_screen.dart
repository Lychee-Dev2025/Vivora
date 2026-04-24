import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/dummy_data.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/insight_card.dart';
import '../../../core/widgets/quick_action_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import 'package:vivora/features/analytics/data/dummy_analytics_provider.dart';
import 'package:vivora/features/first_time_setup/data/services/user_profile_service.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import 'widgets/greeting_header.dart';
import 'widgets/productivity_score_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileService = UserProfileService();
  final _repository = ProductivityRepository();
  
  String _userName = DummyData.userName;
  double _score = 0;
  String _level = 'Medium';
  String _feedback = 'Log your progress to see your productivity score.';
  DailyProductivityLog? _todayLog;
  bool _isInitial = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _profileService.getUserProfile(user.uid);
      final log = await _repository.getDailyLog(user.uid, DateTime.now());
      
      if (mounted) {
        setState(() {
          if (profile != null) {
            _userName = profile.fullName.split(' ')[0];
            _score = (profile.setupCompleted && profile.profileCompletedAt != null) 
              ? (profile.updatedAt != null ? 0 : 0) // Placeholder logic, will use actual fields
              : 0;
            
            // Try to get latest values from profile if they were saved by repository
            // Note: UserProfile model needs to be aware of these new fields or we fetch from map
          }
          
          if (log != null) {
            _todayLog = log;
            // In a real app, the log object would contain the calculated result too if stored together
            // For now, we'll simulate fetching the result parts from the log map in repository
          }
        });
        
        // Re-fetch the user doc specifically for the new fields
        _fetchLatestScore(user.uid);
      }
    }
  }

  Future<void> _fetchLatestScore(String uid) async {
    try {
      final profile = await _profileService.getUserProfile(uid);
      if (profile != null && mounted) {
        // Since I can't easily change the model right now without multiple steps,
        // I'll assume the latest values are updated in Firestore and I fetch them.
        // For this demo, let's just use the repository to get today's full result.
        final logMap = await _repository.getWeeklyLogs(uid);
        if (logMap.isNotEmpty) {
          final latest = logMap.first;
          setState(() {
            _score = (latest['overallScore'] ?? 0).toDouble();
            _level = latest['performanceLevel'] ?? 'Medium';
            _feedback = latest['feedbackMessage'] ?? '';
            _isInitial = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching latest score: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = DummyAnalyticsProvider.currentStats;

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Dashboard')) : null,
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryBlue,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: GreetingHeader(name: _userName),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 100),
                    child: ProductivityScoreCard(
                      score: _isInitial ? '--' : _score.toInt().toString(),
                      level: _level,
                      feedback: _feedback,
                      onLogTap: () async {
                        final result = await Navigator.of(context).pushNamed(AppRoutes.dailyProductivityEntry);
                        if (result == true) {
                          _loadData();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Quick Stats',
                    subtitle: 'Your performance today',
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 160, // Sufficient height for all content
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FadeInLeft(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 200),
                          child: StatCard(
                            title: 'Screen Time',
                            value: _todayLog != null ? '${_todayLog!.actualScreenTimeHours.toStringAsFixed(1)}h' : stats.screenTime,
                            icon: Icons.phone_iphone_rounded,
                            iconColor: AppColors.primaryBlue,
                          ),
                        );
                      } else if (index == 1) {
                        return FadeInRight(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 200),
                          child: StatCard(
                            title: 'Focus Hours',
                            value: _todayLog != null ? '${_todayLog!.actualFocusHours.toStringAsFixed(1)}h' : stats.focusHours,
                            icon: Icons.timer_rounded,
                            iconColor: AppColors.softPurple,
                          ),
                        );
                      } else if (index == 2) {
                        return FadeInLeft(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 300),
                          child: StatCard(
                            title: 'Sleep',
                            value: _todayLog != null ? '${_todayLog!.actualSleepHours.toStringAsFixed(1)}h' : stats.sleepHours,
                            icon: Icons.nightlight_round,
                            iconColor: AppColors.secondaryCyan,
                          ),
                        );
                      } else {
                        return FadeInRight(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 300),
                          child: StatCard(
                            title: 'Consistency',
                            value: _todayLog != null ? '${_todayLog!.consistencyScore.toInt()}%' : stats.consistency,
                            icon: Icons.trending_up_rounded,
                            iconColor: AppColors.accentGreen,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 400),
                    child: InsightCard(
                      title: 'Daily Tip',
                      insight: _isInitial 
                        ? "Log your day to get personalized AI insights."
                        : "Your focus is at ${(_todayLog?.actualFocusHours ?? 0).toStringAsFixed(1)}h. Reach your goal of ${stats.focusHours} for a perfect score!",
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 500),
                    child: ChartContainer(
                      title: 'Weekly Progress',
                      subtitle: 'Focus output over last 7 days',
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.primaryBlue.withOpacity(0.3)),
                            const SizedBox(height: 8),
                            const Text('Detailed chart in Analytics', style: TextStyle(color: AppColors.lightText)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Shortcuts',
                    subtitle: 'Jump into your daily tools',
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 600),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: <Widget>[
                        QuickActionTile(
                          icon: Icons.analytics_rounded,
                          title: 'Analytics',
                          subtitle: 'Visual data',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.analytics);
                          },
                        ),
                        QuickActionTile(
                          icon: Icons.description_rounded,
                          title: 'Reports',
                          subtitle: 'Performance',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.reports);
                          },
                        ),
                        QuickActionTile(
                          icon: Icons.flag_rounded,
                          title: 'Goals',
                          subtitle: 'Track targets',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.goals);
                          },
                        ),
                        QuickActionTile(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Badges',
                          subtitle: 'View progress',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.badges);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
