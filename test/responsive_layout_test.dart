import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/core/theme/app_colors.dart';
import 'package:vivora/core/widgets/chart_container.dart';
import 'package:vivora/core/widgets/quick_action_tile.dart';
import 'package:vivora/core/widgets/stat_card.dart';
import 'package:vivora/features/activity_monitoring/data/services/activity_sync_service.dart';
import 'package:vivora/features/activity_monitoring/presentation/widgets/tracking_status_card.dart';
import 'package:vivora/features/analytics/data/models/analytics_models.dart';
import 'package:vivora/features/analytics/presentation/widgets/productivity_charts.dart';

import 'support/fakes.dart';

Future<List<FlutterErrorDetails>> _collectErrors(
  WidgetTester tester,
  Widget Function(double width) build,
) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    for (final width in <double>[320, 360, 393, 430, 600]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: build(width),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }
  } finally {
    FlutterError.onError = previousOnError;
  }
  return errors;
}

void main() {
  testWidgets('dashboard and analytics cards fit narrow and scaled layouts', (
    tester,
  ) async {
    final service = ActivitySyncService(
      dataSource: FakeDataSource(),
      repository: FakeActivityRepository(),
      currentUserId: () => 'user-a',
    );
    await service.syncNow(force: true);

    final errors = await _collectErrors(
      tester,
      (width) => Column(
        children: <Widget>[
          const StatCard(
            title: 'Screen Unlocked',
            value: '21h 53m',
            subtitle: 'Measured',
            icon: Icons.phone_iphone_rounded,
            iconColor: AppColors.primaryBlue,
          ),
          const SizedBox(height: 12),
          const ChartContainer(
            title: 'Weekly Productivity',
            subtitle: 'Saved scores · 3 of 7 days logged',
            child: Text('No data'),
          ),
          const SizedBox(height: 12),
          const QuickActionTile(
            icon: Icons.analytics_rounded,
            title: 'Analytics',
            subtitle: 'Visual data',
            onTap: _noop,
          ),
          const SizedBox(height: 12),
          TrackingStatusCard(service: service),
        ],
      ),
    );
    expect(
      errors.where((d) => d.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
    expect(find.textContaining('Vivora (22m)'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget); // app usage, not screen-on time
  });

  testWidgets('charts render with zero, one and many points', (tester) async {
    for (final points in <List<ChartDataPoint>>[
      const <ChartDataPoint>[],
      const <ChartDataPoint>[ChartDataPoint('Wed', 72)],
      const <ChartDataPoint>[
        ChartDataPoint('Mon', 40),
        ChartDataPoint('Tue', 0),
        ChartDataPoint('Wed', 95),
      ],
    ]) {
      final errors = await _collectErrors(
        tester,
        (width) => Column(
          children: <Widget>[
            ChartContainer(
              title: 'Line',
              child: WeeklyProductivityChart(data: points, maxY: 100),
            ),
            ChartContainer(
              title: 'Bars',
              child: SleepTrendChart(data: points),
            ),
            ChartContainer(
              title: 'Ratio',
              height: null,
              child: FocusVsDistractionChart(data: points),
            ),
          ],
        ),
      );
      expect(errors, isEmpty, reason: 'points: ${points.length}');
    }
  });
}

void _noop() {}
