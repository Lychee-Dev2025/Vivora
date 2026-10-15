import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/activity_monitoring/data/services/activity_sync_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The saved appearance is read before the first frame so the app never
  // starts in the wrong theme.
  await Future.wait<void>(<Future<void>>[
    ThemeController.init(),
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then(
      (_) => debugPrint('Firebase initialized successfully'),
      onError: (Object e) => debugPrint('Error initializing Firebase: $e'),
    ),
  ]);
  runApp(const VivoraApp());
}

class VivoraApp extends StatefulWidget {
  const VivoraApp({super.key});

  @override
  State<VivoraApp> createState() => _VivoraAppState();
}

class _VivoraAppState extends State<VivoraApp> with WidgetsBindingObserver {
  final ActivitySyncService _activitySyncService = ActivitySyncService.instance;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Firebase.apps.isNotEmpty) {
      // Sync whenever a user signs in, and drop the previous user's in-memory
      // data on sign-out or account switch.
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        User? user,
      ) {
        _activitySyncService.onUserChanged(user?.uid);
        if (user != null) {
          unawaited(_activitySyncService.syncIfNeeded());
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Usage Access settings or another app: re-read permissions
    // and recapture (throttled, so quick app switches do not re-query).
    if (state == AppLifecycleState.resumed && Firebase.apps.isNotEmpty) {
      unawaited(_activitySyncService.syncIfNeeded());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (BuildContext context, ThemeMode mode, Widget? child) {
        // Read from the platform: there is no MediaQuery above MaterialApp.
        final bool reduceMotion = WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
        return MaterialApp(
          title: 'Vivora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          // Short cross-fade between themes; none when the device asks for
          // reduced motion.
          themeAnimationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
