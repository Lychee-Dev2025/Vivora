import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/vivora_palette.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../behavior_analysis/domain/behavior_models.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../insights/services/insights_service.dart';

/// Streams the signed-in user's profile into [ProfileView].
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;
    return StreamBuilder<UserProfile?>(
      stream: user != null
          ? UserProfileService().getUserProfileStream(user.uid)
          : Stream<UserProfile?>.value(null),
      builder: (context, snapshot) => ProfileView(
        profile: snapshot.data,
        loading: snapshot.connectionState == ConnectionState.waiting,
        loadFailed: snapshot.hasError,
        fallbackEmail: user?.email,
        showAppBar: showAppBar,
        insights: InsightsService.instance.snapshot,
        onSignOut: auth.signOut,
      ),
    );
  }
}

/// The Profile layout, driven entirely by its parameters. Only fields that
/// exist in [UserProfile] are shown; nothing is invented.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.insights,
    this.loading = false,
    this.loadFailed = false,
    this.fallbackEmail,
    this.showAppBar = false,
    this.onSignOut,
  });

  final UserProfile? profile;
  final bool loading;
  final bool loadFailed;
  final String? fallbackEmail;
  final ValueListenable<InsightsSnapshot?> insights;
  final bool showAppBar;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final UserProfile? profile = this.profile;
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const AppBarTitle('Profile')) : null,
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxxl),
          children: <Widget>[
            if (!showAppBar) ...<Widget>[
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: Space.lg),
            ],
            _ProfileHeader(
              profile: profile,
              email: (profile?.email ?? '').isNotEmpty
                  ? profile!.email
                  : (fallbackEmail ?? ''),
              loading: loading,
            ),
            const SizedBox(height: Space.xl),
            ValueListenableBuilder<InsightsSnapshot?>(
              valueListenable: insights,
              builder: (context, snapshot, _) => _ProductivityOverview(
                analysis: snapshot?.analyses[AnalysisPeriod.month],
              ),
            ),
            const SizedBox(height: Space.xl),
            if (loadFailed)
              const Padding(
                padding: EdgeInsets.only(bottom: Space.xl),
                child: StateMessage.error(
                  message:
                      'Your profile details could not be loaded. Check your connection; they will appear automatically.',
                ),
              )
            else if (!loading && profile == null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xl),
                child: StateMessage(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Complete your profile',
                  message:
                      'Add your name and study details so Vivora can personalise your goals.',
                  actionLabel: 'Edit profile',
                  onAction: () =>
                      Navigator.of(context).pushNamed(AppRoutes.editProfile),
                ),
              ),
            if (profile != null) ...<Widget>[
              SectionCard(
                title: 'PERSONAL',
                children: <Widget>[
                  InfoRow(
                    icon: Icons.badge_rounded,
                    title: 'Full name',
                    value: profile.fullName,
                  ),
                  InfoRow(
                    icon: Icons.cake_rounded,
                    title: 'Age range',
                    value: profile.ageRange,
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              SectionCard(
                title: 'ACADEMIC',
                children: <Widget>[
                  InfoRow(
                    icon: Icons.school_rounded,
                    title: 'Academic level',
                    value: profile.academicLevel,
                  ),
                  InfoRow(
                    icon: Icons.account_balance_rounded,
                    title: 'Institution',
                    value: profile.institution,
                  ),
                  InfoRow(
                    icon: Icons.menu_book_rounded,
                    title: 'Field of study',
                    value: profile.fieldOfStudy,
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              SectionCard(
                title: 'ROUTINE',
                children: <Widget>[
                  InfoRow(
                    icon: Icons.wb_twilight_rounded,
                    title: 'Wake-up / sleep',
                    value: _join(<String>[
                      profile.routineProfile.wakeUpTime,
                      profile.routineProfile.sleepTime,
                    ], ' – '),
                  ),
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    title: 'Preferred study time',
                    value: profile.routineProfile.preferredStudyTime,
                  ),
                  InfoRow(
                    icon: Icons.flag_circle_rounded,
                    title: 'Main challenge',
                    value: profile.routineProfile.mainDailyChallenge,
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              SectionCard(
                title: 'GOALS',
                trailing: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.goals),
                  child: const Text('Manage'),
                ),
                children: <Widget>[
                  InfoRow(
                    icon: Icons.track_changes_rounded,
                    title: 'Main goal',
                    value: profile.goals.productivityGoalType,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.goals),
                  ),
                  InfoRow(
                    icon: Icons.insights_rounded,
                    title: 'Daily targets',
                    value: _join(<String>[
                      if (profile.goals.targetSleepHours.isNotEmpty)
                        'Sleep ${profile.goals.targetSleepHours}',
                      if (profile.goals.targetStudyHours.isNotEmpty)
                        'Study ${profile.goals.targetStudyHours}',
                      if (profile.goals.targetFocusHours.isNotEmpty)
                        'Focus ${profile.goals.targetFocusHours}',
                      if (profile.goals.targetScreenTimeLimit.isNotEmpty)
                        'Screen ≤ ${profile.goals.targetScreenTimeLimit}',
                    ], ' · '),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.goals),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
            ],
            SectionCard(
              title: 'ACCOUNT & APP',
              children: <Widget>[
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance,
                  builder: (context, mode, _) => InfoRow(
                    icon: Icons.palette_rounded,
                    title: 'Appearance',
                    value: themeModeLabel(mode),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                ),
                InfoRow(
                  icon: Icons.security_rounded,
                  title: 'Tracking & permissions',
                  value: 'Usage access, activity, sync status',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                ),
                InfoRow(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  color: context.palette.danger,
                  onTap: () => _confirmSignOut(context),
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Log out of Vivora?'),
        content: const Text(
          'Your data stays saved in your account. You can sign in again at any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.danger,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onSignOut?.call();
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
    }
  }

  static String _join(List<String> parts, String separator) =>
      parts.where((p) => p.trim().isNotEmpty).join(separator);
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System default',
};

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.email,
    required this.loading,
  });

  final UserProfile? profile;
  final String email;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final VivoraPalette p = context.palette;
    final String name = (profile?.fullName ?? '').trim();
    final String academic = <String>[
      profile?.academicLevel ?? '',
      profile?.fieldOfStudy ?? '',
      profile?.institution ?? '',
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        gradient: p.highlightGradient,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.onHighlight.withValues(alpha: 0.25),
                ),
                child: InitialsAvatar(
                  name: name.isEmpty ? email : name,
                  size: 64,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      loading && name.isEmpty
                          ? 'Loading…'
                          : (name.isEmpty ? 'Your profile' : name),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: p.onHighlight,
                      ),
                    ),
                    if (email.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          color: p.onHighlight.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (academic.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.school_rounded, size: 18, color: p.onHighlight),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    academic,
                    style: TextStyle(
                      color: p.onHighlight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.lg),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.onHighlight,
              side: BorderSide(color: p.onHighlight.withValues(alpha: 0.6)),
              minimumSize: const Size(48, 44),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact numbers from Module 3's 30-day analysis (no new calculations).
class _ProductivityOverview extends StatelessWidget {
  const _ProductivityOverview({required this.analysis});

  final BehaviorAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final BehaviorAnalysis? a = analysis;
    if (a == null) {
      return const SectionCard(
        title: 'LAST 30 DAYS',
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(Space.lg),
            child: LinearProgressIndicator(),
          ),
        ],
      );
    }
    if (!a.hasAnyData) {
      return const StateMessage(
        icon: Icons.insights_rounded,
        title: 'No activity yet',
        message:
            'Log your day or allow usage tracking to see your streak, average score and focus time here.',
      );
    }
    final MetricStats score = a.metrics['score']!;
    final double focusTotal = a.metrics['focusSessionMinutes']!.total ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
          child: Text(
            'LAST 30 DAYS',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ResponsiveCardGrid(
          minCardWidth: 120,
          children: <Widget>[
            StatCard(
              title: 'Logging streak',
              value: '${a.loggingStreak} day${a.loggingStreak == 1 ? '' : 's'}',
              subtitle: 'Best ${a.bestLoggingStreak}',
              icon: Icons.local_fire_department_rounded,
              iconColor: Colors.orange,
            ),
            StatCard(
              title: 'Average score',
              value: score.mean == null ? '--' : '${score.mean!.round()}',
              subtitle: '${score.count} scored days',
              icon: Icons.speed_rounded,
            ),
            StatCard(
              title: 'Focus Mode time',
              value: formatMinutes(focusTotal.round()),
              subtitle: 'Timed sessions',
              icon: Icons.timer_rounded,
              iconColor: Colors.teal,
            ),
            StatCard(
              title: 'Days logged',
              value: '${a.dataQuality.loggedDays}/30',
              subtitle: 'Daily progress logs',
              icon: Icons.event_available_rounded,
              iconColor: Colors.indigo,
            ),
          ],
        ),
      ],
    );
  }
}
