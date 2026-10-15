import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vivora/core/theme/app_theme.dart';

/// Logical phone widths and Android font scales from the responsiveness spec.
const List<double> kWidths = <double>[320, 360, 375, 393, 412, 430, 480];
const List<double> kScales = <double>[1.0, 1.15, 1.3, 1.45, 1.5, 1.75];

/// 640: a short phone (or one with the keyboard/navigation taking space).
/// 5000: tall enough that every lazily built list item is laid out and checked.
const List<double> kHeights = <double>[640, 5000];

/// Renders [build] in a phone-sized window with the real app theme, status and
/// navigation bar insets and the given font scale, then reports every layout
/// problem: Flutter layout exceptions (RenderFlex overflow etc.) and text that
/// was cut short by an ellipsis or a line limit.
Future<List<String>> layoutIssues(
  WidgetTester tester,
  Widget Function() build, {
  required double width,
  required double height,
  required double scale,
  Future<void> Function(WidgetTester tester)? interact,
  Set<String> allowTruncated = const <String>{},
  Duration settle = const Duration(seconds: 3),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  const double dpr = 2.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(width * dpr, height * dpr);
  tester.view.padding = const FakeViewPadding(top: 24 * dpr, bottom: 48 * dpr);
  tester.view.viewPadding = const FakeViewPadding(
    top: 24 * dpr,
    bottom: 48 * dpr,
  );
  tester.platformDispatcher.textScaleFactorTestValue = scale;

  final List<String> issues = <String>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    issues.add(details.exceptionAsString().split('\n').first);
  };
  try {
    // Fresh tree each time: otherwise State (and timers) of the previous
    // layout survive into this one.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: build(),
      ),
    );
    // Let entrance animations (animate_do) and delayed loads finish.
    await tester.pump(settle);
    if (interact != null) {
      await interact(tester);
      await tester.pump(const Duration(seconds: 1));
    }
  } finally {
    FlutterError.onError = previous;
  }

  for (final Element element in find.byType(RichText).evaluate()) {
    final RenderParagraph paragraph = element.renderObject! as RenderParagraph;
    final String text = paragraph.text.toPlainText();
    if (paragraph.didExceedMaxLines && !allowTruncated.contains(text)) {
      issues.add('truncated text: "$text"');
    }
  }
  return issues;
}

/// Runs [layoutIssues] over the whole width × scale × height matrix and fails
/// once with every problem found, labelled by the layout that produced it.
Future<void> expectResponsive(
  WidgetTester tester,
  Widget Function() build, {
  List<double> widths = kWidths,
  List<double> scales = kScales,
  List<double> heights = kHeights,
  Future<void> Function(WidgetTester tester)? interact,
  Set<String> allowTruncated = const <String>{},
  Duration settle = const Duration(seconds: 3),
  List<ThemeMode> themes = const <ThemeMode>[ThemeMode.light, ThemeMode.dark],
}) async {
  final List<String> failures = <String>[];
  for (final ThemeMode theme in themes) {
    for (final double height in heights) {
      for (final double width in widths) {
        for (final double scale in scales) {
          final List<String> issues = await layoutIssues(
            tester,
            build,
            width: width,
            height: height,
            scale: scale,
            interact: interact,
            allowTruncated: allowTruncated,
            settle: settle,
            themeMode: theme,
          );
          for (final String issue in issues.toSet()) {
            failures.add(
              '${theme.name} ${width.toInt()}x${height.toInt()} @${scale}x: $issue',
            );
          }
        }
      }
    }
  }
  // Leave the next test with a clean view.
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  expect(failures, isEmpty, reason: failures.take(40).join('\n'));
}
