import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/vivora_palette.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../activity_monitoring/data/services/activity_sync_service.dart';
import '../../activity_monitoring/presentation/widgets/tracking_status_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.themeController});

  /// Defaults to the app-wide controller; injectable for tests.
  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final ActivitySyncService activityService = ActivitySyncService.instance;
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Settings')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxxl),
          children: <Widget>[
            AppearanceSelector(
              controller: themeController ?? ThemeController.instance,
            ),
            const SizedBox(height: Space.xxl),
            Padding(
              padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
              child: Text(
                'TRACKING',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.palette.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            TrackingStatusCard(),
            const SizedBox(height: Space.xxl),
            SectionCard(
              title: 'PERMISSIONS & DATA',
              children: <Widget>[
                InfoRow(
                  icon: Icons.query_stats_rounded,
                  title: 'Usage access',
                  value: 'Open Android Usage Access settings',
                  onTap: activityService.openUsageAccessSettings,
                ),
                InfoRow(
                  icon: Icons.directions_walk_rounded,
                  title: 'Physical activity permission',
                  value: 'Needed for walking/running minutes',
                  onTap: activityService.requestActivityPermission,
                ),
                InfoRow(
                  icon: Icons.info_outline_rounded,
                  title: 'How usage is measured',
                  onTap: () => showMeasurementInfo(context),
                ),
              ],
            ),
            const SizedBox(height: Space.xxl),
            SectionCard(
              title: 'ABOUT',
              children: <Widget>[
                InfoRow(
                  icon: Icons.favorite_outline_rounded,
                  title: 'About Vivora',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Vivora',
                    applicationLegalese:
                        'Student productivity monitoring. Usage data is read on this phone '
                        'with your permission and stored only in your own Firebase account records.',
                  ),
                ),
                InfoRow(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  color: context.palette.danger,
                  trailing: const SizedBox.shrink(),
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Log out of Vivora?'),
        content: const Text('Your data stays saved in your account.'),
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
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
    }
  }

  static void showMeasurementInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('How usage is measured'),
        content: const Text(
          '• App usage: time each app was in the foreground, from Android usage events '
          '(an activity counts from "resumed" to "paused"). The home screen and background '
          'system components are excluded, matching Digital Wellbeing.\n\n'
          '• Screen unlocked: time the screen was on and unlocked, including the home screen. '
          'Lock-screen glances are excluded.\n\n'
          '• Each sync recomputes the whole day, so syncing again never adds time twice.\n\n'
          '• Small differences from Digital Wellbeing (usually under a minute per app) are expected: '
          'Digital Wellbeing uses private system data and its own rounding.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Light / Dark / System default. Applies immediately and is remembered.
class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({super.key, required this.controller});

  final ThemeController controller;

  static const List<(ThemeMode, IconData, String, String)> options =
      <(ThemeMode, IconData, String, String)>[
        (
          ThemeMode.system,
          Icons.brightness_auto_rounded,
          'System default',
          'Follow your phone\'s appearance setting',
        ),
        (
          ThemeMode.light,
          Icons.light_mode_rounded,
          'Light',
          'Bright background',
        ),
        (
          ThemeMode.dark,
          Icons.dark_mode_rounded,
          'Dark',
          'Dark navy background, easier at night',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => SectionCard(
        title: 'APPEARANCE',
        children: <Widget>[
          for (final (
                ThemeMode m,
                IconData icon,
                String title,
                String description,
              )
              in options)
            Semantics(
              selected: m == mode,
              inMutuallyExclusiveGroup: true,
              child: InfoRow(
                icon: icon,
                title: title,
                value: description,
                onTap: () => controller.setMode(m),
                trailing: m == mode
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: 'Selected',
                      )
                    : Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: context.palette.textSecondary,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
