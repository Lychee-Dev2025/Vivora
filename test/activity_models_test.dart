import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_date_utils.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_state.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/models/daily_activity_log.dart';
import 'package:vivora/features/activity_monitoring/data/repositories/activity_repository.dart';
import 'package:vivora/features/activity_monitoring/data/services/android_activity_bridge.dart';
import 'package:vivora/features/activity_monitoring/data/services/app_category_service.dart';

import 'support/fakes.dart';

void main() {
  group('day identity', () {
    test('the document id, not the stored timestamp, decides the day', () {
      // Written by the previous build as "UTC midnight": on a UTC-5 phone this
      // instant is the previous evening locally.
      final log = DailyActivityLog.fromMap(<String, dynamic>{
        'date': Timestamp.fromDate(DateTime.utc(2026, 10, 14)),
        'trackedApplicationMinutes': 45,
      }, documentId: '2026_10_14');
      expect(log.date, DateTime(2026, 10, 14));
      expect(log.appUsageMinutes, 45, reason: 'legacy field name is read');
    });

    test('day window is half-open [midnight, next midnight)', () {
      final range = ActivityDateUtils.currentDayRange(
        DateTime(2026, 10, 14, 23, 59),
      );
      expect(range.start, DateTime(2026, 10, 14));
      expect(range.end, DateTime(2026, 10, 15));
    });

    test('keys round-trip and month/year boundaries are handled', () {
      expect(ActivityDateUtils.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(
        ActivityDateUtils.documentIdFor(DateTime(2026, 1, 5)),
        '2026_01_05',
      );
      expect(ActivityDateUtils.parseKey('2026_01_05'), DateTime(2026, 1, 5));
      expect(ActivityDateUtils.parseKey('garbage'), isNull);
      final days = ActivityDateUtils.lastDays(DateTime(2026, 1, 2, 10), 4);
      expect(days.map(ActivityDateUtils.dayKey), <String>[
        '2025-12-30',
        '2025-12-31',
        '2026-01-01',
        '2026-01-02',
      ]);
    });

    test(
      'a written log stores the true local-midnight instant and a day key',
      () {
        final map = DailyActivityLog(
          date: DateTime(2026, 10, 14, 13, 5),
        ).toMap();
        expect((map['date'] as Timestamp).toDate(), DateTime(2026, 10, 14));
        expect(map['dateKey'], '2026-10-14');
      },
    );
  });

  test('compact app summary round-trips and is stored as a list', () {
    final DailyActivityLog log = DailyActivityLog(
      date: DateTime(2026, 10, 15),
      appSummary: <AppUsageEntry>[
        app(
          'com.whatsapp',
          'WhatsApp',
          const Duration(minutes: 13),
          category: AppCategory.neutral,
        ),
      ],
    );
    final Map<String, dynamic> map = log.toMap();
    expect(
      map['appSummary'],
      isA<List<dynamic>>(),
      reason: 'a list is replaced, not deep-merged',
    );
    final DailyActivityLog back = DailyActivityLog.fromMap(
      map,
      documentId: '2026_10_15',
    );
    expect(back.appSummary!.single.packageName, 'com.whatsapp');
    expect(
      back.appSummary!.single.foregroundDuration,
      const Duration(minutes: 13),
    );
    expect(back.appSummary!.single.category, AppCategory.neutral);
    expect(
      back.appSummary!.single.iconBase64,
      isNull,
      reason: 'no icons in history',
    );
    expect(
      DailyActivityLog.fromMap(
        <String, dynamic>{},
        documentId: '2026_10_15',
      ).appSummary,
      isNull,
    );
  });
  group('native capture parsing', () {
    test(
      'maps the two screen metrics separately and keeps exact durations',
      () {
        final capture = AndroidActivityBridge.parseCapture(
          <String, dynamic>{
            'totalScreenTimeMinutes': 52,
            'trackedApplicationMinutes': 45,
            'phoneUnlockCount': 14,
            'movementStatus': 'permissionDenied',
            'usagePermissionGranted': true,
            'syncStatus': 'success',
            'appUsageEntries': <Map<String, dynamic>>[
              <String, dynamic>{
                'packageName': 'com.whatsapp',
                'appName': 'WhatsApp',
                'usageMinutes': 6,
                'foregroundDurationMillis': 360000,
                'lastUsedAt': 1760432400000,
              },
            ],
          },
          start: DateTime(2026, 10, 14),
          end: DateTime(2026, 10, 15),
        );

        expect(capture.screenTimeMinutes, 52);
        expect(capture.appUsageMinutes, 45);
        expect(capture.syncStatus, ActivitySyncState.success);
        final whatsapp = capture.appUsageEntries.single;
        expect(whatsapp.foregroundDuration, const Duration(minutes: 6));
        expect(whatsapp.lastUsedAt, isNotNull);
      },
    );

    test('an unavailable metric stays null instead of becoming zero', () {
      final capture = AndroidActivityBridge.parseCapture(
        <String, dynamic>{
          'totalScreenTimeMinutes': null,
          'trackedApplicationMinutes': 0,
          'usagePermissionGranted': true,
          'syncStatus': 'success',
        },
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 15),
      );
      expect(capture.screenTimeMinutes, isNull);
      expect(capture.appUsageMinutes, 0);
    });
  });

  group('app usage entries', () {
    test(
      'stale entries from an older capture are ignored; short real use is kept',
      () {
        final entries = <AppUsageEntry>[
          app(
            'com.facebook.katana',
            'Facebook',
            const Duration(minutes: 75),
            captureId: 'old',
          ),
          app(
            'com.whatsapp',
            'WhatsApp',
            const Duration(seconds: 20),
            captureId: 'new',
          ),
          app(
            'com.google.android.youtube',
            'YouTube',
            const Duration(minutes: 11),
            captureId: 'new',
          ),
          app('com.idle', 'Idle', Duration.zero, captureId: 'new'),
        ];
        final current = ActivityRepository.filterCurrentCapture(entries, 'new');
        expect(current.map((e) => e.packageName), <String>[
          'com.google.android.youtube',
          'com.whatsapp',
        ]);
        expect(current.last.durationLabel, '<1m');
      },
    );

    test('Firestore Timestamp and int millis both parse as lastUsedAt', () {
      final fromTimestamp = AppUsageEntry.fromMap(<String, dynamic>{
        'lastUsedAt': Timestamp.fromDate(DateTime(2026, 10, 14, 10)),
      });
      expect(fromTimestamp.lastUsedAt, DateTime(2026, 10, 14, 10));
    });

    test('duration labels', () {
      expect(formatUsageDuration(Duration.zero), '0m');
      expect(formatUsageDuration(const Duration(seconds: 20)), '<1m');
      expect(formatUsageDuration(const Duration(minutes: 65)), '1h 05m');
    });
  });

  group('AppCategoryService', () {
    const service = AppCategoryService();
    AppCategory cat(String pkg, String name) =>
        service.resolveCategory(packageName: pkg, appName: name);

    test('known apps', () {
      expect(cat('com.facebook.katana', 'Facebook'), AppCategory.distracting);
      expect(
        cat('com.google.android.youtube', 'YouTube'),
        AppCategory.distracting,
      );
      expect(cat('com.whatsapp', 'WhatsApp'), AppCategory.neutral);
      expect(cat('com.android.deskclock', 'Clock'), AppCategory.neutral);
    });

    test('unknown apps stay uncategorized and substrings do not misfire', () {
      expect(
        cat('com.example.unknown', 'Unknown App'),
        AppCategory.uncategorized,
      );
      // The old substring rule classified barcode scanners as productive ("code").
      expect(
        cat('com.scanner.barcode', 'Barcode Scanner'),
        AppCategory.uncategorized,
      );
    });

    test('user overrides always win', () {
      final entry = service.categorizeEntry(
        app(
          'com.google.android.youtube',
          'YouTube',
          const Duration(minutes: 3),
        ),
        overrides: <String, AppCategory>{
          'com.google.android.youtube': AppCategory.productive,
        },
      );
      expect(entry.category, AppCategory.productive);
      expect(entry.categoryIsUserOverride, isTrue);
    });
  });
}
