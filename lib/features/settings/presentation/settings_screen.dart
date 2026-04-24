import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/secondary_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: GradientBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            AnimatedPageWrapper(
              delay: const Duration(milliseconds: 30),
              child: Text(
                'Preferences',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedPageWrapper(
              delay: const Duration(milliseconds: 80),
              child: InfoCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      title: const Text('Notifications'),
                      subtitle: const Text('Allow daily reminders'),
                      value: true,
                      onChanged: (bool value) {},
                      activeTrackColor: AppColors.primaryBlue,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Dark Mode Display'),
                      subtitle: const Text('Follow system settings'),
                      value: false,
                      onChanged: (bool value) {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('App Permissions'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('About Vivora'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedPageWrapper(
              delay: const Duration(milliseconds: 140),
              child: SecondaryButton(
                label: 'Log Out',
                expanded: true,
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.auth,
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
