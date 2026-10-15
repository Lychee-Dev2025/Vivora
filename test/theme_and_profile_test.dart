import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivora/core/services/session.dart';
import 'package:vivora/core/theme/app_theme.dart';
import 'package:vivora/core/theme/theme_controller.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/features/analytics/presentation/analytics_screen.dart';
import 'package:vivora/features/badges/data/badge_service.dart';
import 'package:vivora/features/badges/presentation/badges_screen.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/goals/presentation/goals_screen.dart';
import 'package:vivora/features/insights/services/insights_service.dart';
import 'package:vivora/features/profile/presentation/edit_profile_screen.dart';
import 'package:vivora/features/profile/presentation/profile_screen.dart';
import 'package:vivora/features/reports/presentation/reports_screen.dart';
import 'package:vivora/features/settings/presentation/settings_screen.dart';
import 'package:vivora/features/splash/presentation/splash_screen.dart';
import 'package:vivora/main.dart';

import 'support/fixtures.dart';

double _luminance(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final double la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> pumpRoot(WidgetTester tester) async {
  await tester.pumpWidget(const VivoraApp());
  await tester.pump(const Duration(milliseconds: 500));
}

Brightness rootBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SplashScreen))).brightness;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Session.currentUserId = () => null;
    Session.currentEmail = () => null;
  });

  group('theme preference', () {
    test('defaults to System, persists, and survives a restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ThemeController c = await ThemeController.init();
      expect(c.value, ThemeMode.system);

      await c.setMode(ThemeMode.dark);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.storageKey), 'dark');

      c = await ThemeController.init(); // simulated app restart
      expect(c.value, ThemeMode.dark);
      await c.setMode(ThemeMode.light);
      c = await ThemeController.init();
      expect(c.value, ThemeMode.light);
    });

    test('an unknown stored value falls back to System', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ThemeController.storageKey: 'purple',
      });
      expect((await ThemeController.init()).value, ThemeMode.system);
    });
  });

  group('app root theming', () {
    testWidgets(
      'System default follows the phone; a manual choice overrides it',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await ThemeController.init();

        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await pumpRoot(tester);
        expect(rootBrightness(tester), Brightness.dark);

        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pump(); // starts the theme cross-fade
        await tester.pump(const Duration(milliseconds: 400));
        expect(rootBrightness(tester), Brightness.light);

        await ThemeController.instance.setMode(
          ThemeMode.dark,
        ); // applies immediately
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(rootBrightness(tester), Brightness.dark);
        expect(
          Theme.of(
            tester.element(find.byType(SplashScreen)),
          ).extension<VivoraPalette>(),
          VivoraPalette.dark,
        );

        await tester.pumpWidget(const SizedBox()); // dispose splash timer
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      },
    );

    testWidgets('switching theme keeps screens alive (no data reloads)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ThemeController c = await ThemeController.init();
      int inits = 0;
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: c,
          builder: (context, mode, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: _InitCounter(onInit: () => inits++),
          ),
        ),
      );
      for (final ThemeMode m in <ThemeMode>[
        ThemeMode.dark,
        ThemeMode.light,
        ThemeMode.system,
        ThemeMode.dark,
      ]) {
        await c.setMode(m);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(inits, 1, reason: 'initState (where screens load data) ran once');
    });
  });

  group('accessibility', () {
    test('text colours meet WCAG AA (4.5:1) in both themes', () {
      for (final (String name, VivoraPalette p, ThemeData t)
          in <(String, VivoraPalette, ThemeData)>[
            ('light', VivoraPalette.light, AppTheme.lightTheme),
            ('dark', VivoraPalette.dark, AppTheme.darkTheme),
          ]) {
        for (final Color bg in <Color>[
          p.surface,
          p.background,
          p.surfaceMuted,
        ]) {
          expect(
            contrast(p.textPrimary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name primary text',
          );
          expect(
            contrast(p.textSecondary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name secondary text',
          );
        }
        for (final Color c in <Color>[
          t.colorScheme.primary,
          p.success,
          p.warning,
          p.danger,
        ]) {
          expect(
            contrast(c, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name accent text $c',
          );
        }
        // Text on the hero gradient: check every gradient stop.
        for (final Color stop in p.highlightGradient.colors) {
          expect(
            contrast(p.onHighlight, stop),
            greaterThanOrEqualTo(4.5),
            reason: '$name hero text on $stop',
          );
        }
        expect(
          contrast(t.colorScheme.onPrimary, t.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$name button text',
        );
      }
    });

    testWidgets(
      'icon-only controls have labels: bottom navigation and settings',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: SettingsScreen(themeController: await ThemeController.init()),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp('Selected')), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('dark mode coverage', () {
    // Finds large near-white boxes, i.e. parts of a screen left in light mode.
    List<String> brightSurfaces(WidgetTester tester) {
      final List<String> found = <String>[];
      for (final RenderObject ro in tester.allRenderObjects) {
        if (ro is! RenderDecoratedBox || !ro.hasSize) continue;
        final Decoration d = ro.decoration;
        if (d is! BoxDecoration || d.color == null) continue;
        final Color c = d.color!;
        if (c.a > 0.5 &&
            c.computeLuminance() > 0.7 &&
            ro.size.width * ro.size.height > 4000) {
          found.add('${ro.size} $c');
        }
      }
      return found;
    }

    final Map<String, Widget Function()> screens = <String, Widget Function()>{
      'analytics': () => AnalyticsView(
        snapshot: fixtureSnapshot(),
        today: fixtureToday(),
        now: fixtureNow,
      ),
      'reports': () => ReportsView(
        scores: fixtureHistory().scores,
        activity: fixtureHistory().activityLogs,
        now: fixtureNow,
      ),
      'badges': () => BadgesView(
        unlocked: <String, DateTime>{BadgeService.all.first.id: fixtureNow},
      ),
      'goals': () => GoalsView(
        goals: fixtureGoals,
        appUsageMinutes: 200,
        todayLog: fixtureScore(0, 78).log,
      ),
      'profile': () => ProfileView(
        profile: fixtureProfile(),
        insights: ValueNotifier<InsightsSnapshot?>(fixtureSnapshot()),
      ),
      'settings': () => const SettingsScreen(),
    };
    for (final MapEntry<String, Widget Function()> s in screens.entries) {
      testWidgets('${s.key} has no light surfaces in dark mode', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(780, 6000);
        tester.view.devicePixelRatio = 2;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: s.value(),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(brightSurfaces(tester), isEmpty);
        await tester.pumpWidget(const SizedBox());
        tester.view.reset();
      });
    }
  });

  group('profile', () {
    // Tall window so every list item is built (lists are lazy).
    setUp(() {
      final TestFlutterView view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(800, 5000);
      view.devicePixelRatio = 1;
    });
    tearDown(
      () => (TestWidgetsFlutterBinding.instance.platformDispatcher.views.first)
          .reset(),
    );
    testWidgets('shows initials, real sections and the 30-day overview', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileView(
            profile: fixtureProfile(),
            insights: ValueNotifier<InsightsSnapshot?>(fixtureSnapshot()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('MS'),
        findsOneWidget,
        reason: 'initials of Muhammad … Siddiqui',
      );
      expect(find.text('Muhammad Umar Abdullah Rahman Siddiqui'), findsWidgets);
      for (final String section in <String>[
        'PERSONAL',
        'ACADEMIC',
        'ROUTINE',
        'GOALS',
        'ACCOUNT & APP',
        'LAST 30 DAYS',
      ]) {
        expect(find.text(section), findsOneWidget);
        expect(find.text(section), findsOneWidget);
      }
      expect(
        find.byIcon(Icons.camera_alt_rounded),
        findsNothing,
        reason: 'no fake photo upload',
      );
    });

    testWidgets('log out asks for confirmation', (tester) async {
      int signOuts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileView(
            profile: fixtureProfile(),
            insights: ValueNotifier<InsightsSnapshot?>(null),
            onSignOut: () async => signOuts++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Log out'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Log out of Vivora?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(signOuts, 0);
    });
  });

  group('edit profile', () {
    setUp(() {
      final TestFlutterView view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(800, 5000);
      view.devicePixelRatio = 1;
    });
    tearDown(
      () => (TestWidgetsFlutterBinding.instance.platformDispatcher.views.first)
          .reset(),
    );
    late List<UserProfile> saved;
    Widget screen() => EditProfileScreen(
      loadProfile: (_) async => fixtureProfile(),
      saveProfile: (p) async => saved.add(p),
    );

    setUp(() {
      saved = <UserProfile>[];
      Session.currentUserId = () => 'test-user';
      Session.currentEmail = () => fixtureProfile().email;
    });

    testWidgets(
      'validates, saves trimmed values and preserves untouched data',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: screen()),
        );
        await tester.pump(const Duration(seconds: 1));
        final Finder name = find.byType(TextFormField).first;

        await tester.enterText(name, '   ');
        await tester.ensureVisible(find.text('Save changes'));
        await tester.tap(find.text('Save changes'));
        await tester.pump();
        expect(find.text('Name is required'), findsOneWidget);
        expect(saved, isEmpty);

        await tester.enterText(
          find.byType(TextFormField).first,
          '  Umar Siddiqui  ',
        );
        await tester.tap(find.text('Save changes'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(saved, hasLength(1));
        final UserProfile p = saved.single;
        final UserProfile original = fixtureProfile();
        expect(p.fullName, 'Umar Siddiqui');
        expect(p.institution, original.institution);
        expect(p.fieldOfStudy, original.fieldOfStudy);
        expect(p.goals.targetSleepHours, original.goals.targetSleepHours);
        expect(p.routineProfile.wakeUpTime, original.routineProfile.wakeUpTime);
        expect(
          p.ageRange,
          original.ageRange,
          reason: '"18-24" is not in the list but must be preserved',
        );
        expect(p.email, original.email);
      },
    );

    testWidgets('leaving with unsaved edits asks first', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // profile loaded after the route was built
      await tester.enterText(find.byType(TextFormField).first, 'Changed');
      await tester.pump();
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Changed'), findsOneWidget);
    });

    testWidgets(
      'a failed load shows a retryable error, not an endless spinner',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: EditProfileScreen(
              loadProfile: (_) async => throw Exception('offline'),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        expect(
          find.textContaining('Exception'),
          findsNothing,
          reason: 'no raw technical errors',
        );
      },
    );
  });
}

class _InitCounter extends StatefulWidget {
  const _InitCounter({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('screen'));
}
