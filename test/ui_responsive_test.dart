import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/core/widgets/chart_container.dart';
import 'package:vivora/core/widgets/report_card.dart';
import 'package:vivora/core/widgets/stat_card.dart';
import 'package:vivora/core/widgets/summary_tile.dart';
import 'package:vivora/features/activity_monitoring/data/services/activity_sync_service.dart';
import 'package:vivora/features/activity_monitoring/presentation/widgets/tracking_status_card.dart';
import 'package:vivora/features/analytics/data/models/analytics_models.dart';
import 'package:vivora/features/analytics/presentation/widgets/productivity_charts.dart';
import 'package:vivora/features/dashboard/presentation/widgets/productivity_score_card.dart';

import 'support/fakes.dart';

const List<double> widths = <double>[320, 360, 393, 430];
const List<double> scales = <double>[1.0, 1.3, 1.5];

/// Pumps [child] in a phone-sized screen and returns layout errors plus any
/// text that was cut short (ellipsis / exceeded maxLines).
Future<({List<String> errors, List<String> truncated})> pumpPhone(
  WidgetTester tester,
  Widget child, {
  required double width,
  required double scale,
}) async {
  final List<String> errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    tester.view.physicalSize = Size(width * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 2400),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = previous;
  }
  final List<String> truncated = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final RenderParagraph paragraph = element.renderObject! as RenderParagraph;
    if (paragraph.didExceedMaxLines) {
      truncated.add(paragraph.text.toPlainText());
    }
  }
  return (errors: errors, truncated: truncated);
}

List<ChartDataPoint> ratio(double productive, double distracting) =>
    <ChartDataPoint>[
      ChartDataPoint('Productive', productive),
      ChartDataPoint('Distracting', distracting),
    ];

void main() {
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('sharePercentages', () {
    test(
      'Case A: 0m / 14m -> 0% / 100%',
      () => expect(sharePercentages(<double>[0, 14]), <int>[0, 100]),
    );
    test(
      'Case B: 30m / 30m -> 50% / 50%',
      () => expect(sharePercentages(<double>[30, 30]), <int>[50, 50]),
    );
    test(
      'Case C: 45m / 15m -> 75% / 25%',
      () => expect(sharePercentages(<double>[45, 15]), <int>[75, 25]),
    );
    test(
      'Case D: 0m / 0m -> no division by zero',
      () => expect(sharePercentages(<double>[0, 0]), <int>[0, 0]),
    );
    test(
      'Case E: 20m / 0m -> 100% / 0%',
      () => expect(sharePercentages(<double>[20, 0]), <int>[100, 0]),
    );
    test('rounded shares always add up to 100', () {
      expect(sharePercentages(<double>[1, 1, 1]).reduce((a, b) => a + b), 100);
      expect(sharePercentages(<double>[10, 20]), <int>[33, 67]);
    });
  });

  group('App Focus Ratio chart', () {
    final cases = <String, (List<ChartDataPoint>, String?)>{
      'A': (ratio(0, 14), '100%'),
      'B': (ratio(30, 30), '50%'),
      'C': (ratio(45, 15), '75%'),
      'D': (ratio(0, 0), null),
      'E': (ratio(20, 0), '100%'),
    };

    for (final MapEntry<String, (List<ChartDataPoint>, String?)> c
        in cases.entries) {
      testWidgets(
        'Case ${c.key} fits inside its card at every width and font scale',
        (tester) async {
          for (final double width in widths) {
            for (final double scale in scales) {
              final result = await pumpPhone(
                tester,
                ChartContainer(
                  title: 'App Focus Ratio (today)',
                  subtitle:
                      'Productive vs distracting app time. Neutral and uncategorized apps are not counted.',
                  height: null,
                  child: FocusVsDistractionChart(data: c.value.$1),
                ),
                width: width,
                scale: scale,
              );
              final where = 'case ${c.key}, width $width, scale $scale';
              expect(result.errors, isEmpty, reason: where);
              expect(result.truncated, isEmpty, reason: where);

              if (c.value.$2 == null) {
                expect(
                  find.textContaining('No productive or distracting'),
                  findsOneWidget,
                  reason: where,
                );
                expect(find.byType(PieChart), findsNothing, reason: where);
                continue;
              }
              // Centre label and both legend rows are present.
              expect(find.text(c.value.$2!), findsOneWidget, reason: where);
              expect(
                find.textContaining('Productive'),
                findsWidgets,
                reason: where,
              );
              expect(
                find.textContaining('Distracting'),
                findsWidgets,
                reason: where,
              );

              // The ring stays inside the card and the legend is below it.
              final Rect card = tester.getRect(find.byType(ChartContainer));
              final Rect ring = tester.getRect(find.byType(PieChart));
              expect(ring.left, greaterThanOrEqualTo(card.left), reason: where);
              expect(ring.right, lessThanOrEqualTo(card.right), reason: where);
              final Rect legendRow = tester.getRect(
                find.textContaining(RegExp(r'\d+m · \d+%')).first,
              );
              final bool besideRing = legendRow.left >= ring.right;
              expect(
                besideRing || legendRow.top >= ring.bottom,
                isTrue,
                reason: '$where: legend overlaps ring',
              );
            }
          }
        },
      );
    }

    testWidgets('legend shows measured durations', (tester) async {
      await pumpPhone(
        tester,
        FocusVsDistractionChart(data: ratio(0, 14)),
        width: 360,
        scale: 1,
      );
      expect(find.text('0m · 0%'), findsOneWidget);
      expect(find.text('14m · 100%'), findsOneWidget);
    });
  });

  group('cards keep full labels', () {
    testWidgets('Quick Stats and analytics stat cards', (tester) async {
      for (final double width in widths) {
        for (final double scale in scales) {
          final result = await pumpPhone(
            tester,
            const ResponsiveCardGrid(
              children: <Widget>[
                StatCard(
                  title: 'App Usage',
                  value: '2h 00m',
                  subtitle: 'Measured',
                  icon: Icons.phone_iphone_rounded,
                ),
                StatCard(
                  title: 'Focus',
                  value: '8h 00m',
                  subtitle: 'Logged',
                  icon: Icons.timer_rounded,
                ),
                StatCard(
                  title: 'Unlocks',
                  value: '42',
                  subtitle: 'Measured',
                  icon: Icons.lock_open_rounded,
                ),
                StatCard(
                  title: 'Top Day',
                  value: 'Wed 14/10 · 80',
                  icon: Icons.star_rounded,
                ),
                StatCard(
                  title: 'Logging Streak',
                  value: '2 day(s)',
                  subtitle: 'Best: 2 in 14 days',
                  icon: Icons.local_fire_department_rounded,
                ),
                StatCard(
                  title: 'Measured App Usage',
                  value: '22m',
                  icon: Icons.phone_iphone_rounded,
                ),
              ],
            ),
            width: width,
            scale: scale,
          );
          final where = 'width $width, scale $scale';
          expect(result.errors, isEmpty, reason: where);
          expect(result.truncated, isEmpty, reason: where);
          for (final String label in <String>[
            'App Usage',
            'Unlocks',
            'Top Day',
            'Logging Streak',
            'Measured',
            'Logged',
          ]) {
            expect(find.text(label), findsWidgets, reason: '$where: $label');
          }
        }
      }
    });

    testWidgets('Productivity Score card', (tester) async {
      for (final double width in widths) {
        for (final double scale in scales) {
          final result = await pumpPhone(
            tester,
            ProductivityScoreCard(
              score: '100',
              level: 'Needs Improvement',
              feedback:
                  'Your weakest area today was sleep (50/100): 4h of 8h goal.',
              onLogTap: () {},
            ),
            width: width,
            scale: scale,
          );
          final where = 'width $width, scale $scale';
          expect(result.errors, isEmpty, reason: where);
          expect(result.truncated, isEmpty, reason: where);
          expect(find.text('Productivity Score'), findsOneWidget);
          expect(find.text('Update Today\'s Progress'), findsOneWidget);
        }
      }
    });

    testWidgets('Automatic Tracking card title is not split', (tester) async {
      final service = ActivitySyncService(
        dataSource: FakeDataSource(),
        repository: FakeActivityRepository(),
        currentUserId: () => 'user-a',
      );
      await service.syncNow(force: true);
      for (final double width in widths) {
        for (final double scale in scales) {
          final result = await pumpPhone(
            tester,
            TrackingStatusCard(service: service),
            width: width,
            scale: scale,
          );
          final where = 'width $width, scale $scale';
          expect(result.errors, isEmpty, reason: where);
          expect(result.truncated, isEmpty, reason: where);

          final Size title = tester.getSize(find.text('Automatic Tracking'));
          // At most two lines: it may wrap between the two words, never inside one.
          expect(title.height, lessThan(3 * 24 * scale), reason: where);
        }
      }
    });

    testWidgets('Report card with a long level and title', (tester) async {
      for (final double width in widths) {
        for (final double scale in scales) {
          final result = await pumpPhone(
            tester,
            ReportCard(
              title: 'Daily Report · Thu 15/10',
              description: 'Your weakest area today was focus.',
              quickStats: const <Map<String, String>>[
                {'label': 'Score', 'value': '78'},
                {'label': 'Focus', 'value': '1h 30m'},
                {'label': 'Level', 'value': 'Needs Improvement'},
              ],
              onTap: () {},
            ),
            width: width,
            scale: scale,
          );
          expect(result.errors, isEmpty, reason: 'width $width, scale $scale');
          expect(
            result.truncated,
            isEmpty,
            reason: 'width $width, scale $scale',
          );
        }
      }
    });
  });

  group('app usage rows', () {
    testWidgets('durations stay right-aligned with long names and categories', (
      tester,
    ) async {
      const rows = <(String, String, String)>[
        ('WhatsApp', 'Neutral', '13m'),
        ('vivora', 'Neutral', '7m'),
        ('Gallery', 'Neutral', '2m'),
        ('Security', 'Uncategorized', '<1m'),
        (
          'A Very Long Application Name That Will Need Two Lines',
          'Uncategorized (your choice)',
          '1h 05m',
        ),
      ];
      for (final double width in widths) {
        for (final double scale in scales) {
          final result = await pumpPhone(
            tester,
            Column(
              children: <Widget>[
                for (final r in rows) ...<Widget>[
                  UsageRow(label: r.$1, subtitle: r.$2, value: r.$3),
                  const Divider(height: 20),
                ],
                SummaryTile(
                  label: rows.last.$1,
                  subtitle: rows.last.$2,
                  value: rows.last.$3,
                  icon: Icons.apps_rounded,
                ),
              ],
            ),
            width: width,
            scale: scale,
          );
          final where = 'width $width, scale $scale';
          expect(result.errors, isEmpty, reason: where);
          expect(result.truncated, isEmpty, reason: where);

          final double right = tester.getRect(find.text('13m')).right;
          for (final String value in <String>['7m', '2m', '<1m']) {
            expect(
              tester.getRect(find.text(value)).right,
              closeTo(right, 0.5),
              reason: '$where: $value',
            );
          }
          // Names never run under the duration.
          final Rect name = tester.getRect(find.text(rows.last.$1).first);
          final Rect duration = tester.getRect(find.text('1h 05m').first);
          expect(name.right, lessThanOrEqualTo(duration.left), reason: where);
          // "Uncategorized" is laid out as one word, not letter by letter.
          final Size category = tester.getSize(find.text('Uncategorized'));
          expect(category.height, lessThan(20 * scale), reason: where);
        }
      }
    });
  });
}
