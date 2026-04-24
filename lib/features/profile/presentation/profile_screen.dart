import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final profileService = UserProfileService();
    final user = auth.currentUser;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Profile'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.darkText),
              actions: <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.settings);
                  },
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            )
          : null,
      body: GradientBackground(
        child: StreamBuilder<UserProfile?>(
          stream: user != null ? profileService.getUserProfileStream(user.uid) : Stream.value(null),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final String name = profile?.fullName ?? 'User';
            final String email = profile?.email ?? user?.email ?? 'No email';
            final String academicLevel = profile?.academicLevel ?? 'Student';
            
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 24),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 40),
                    child: Center(
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: AppColors.shadowColor,
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                          image: const DecorationImage(
                            image: AssetImage('assets/logo/logo.png'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: AppColors.primaryBlue,
                            width: 3.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 90),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 140),
                    child: Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 160),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        academicLevel,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 190),
                    child: InfoCard(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.orangeAccent,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Current Streak',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lightText),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '5 Days',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkText),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: AppColors.lightText.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                const Icon(
                                  Icons.stars_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Focus Level',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lightText),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.goals.productivityGoalType ?? 'High',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 240),
                    child: SecondaryButton(
                      label: 'Edit Profile',
                      expanded: true,
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.editProfile);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedPageWrapper(
                    delay: const Duration(milliseconds: 290),
                    child: TextButton(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.auth,
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFFF5A5A),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
