import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_snapshot.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_state.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/services/activity_sync_service.dart';

import 'support/fakes.dart';

void main() {
  late FakeDataSource device;
  late FakeActivityRepository cloud;
  String? uid;
  DateTime now = DateTime(2026, 10, 14, 15, 0);

  ActivitySyncService build({Duration ack = const Duration(milliseconds: 50)}) {
    return ActivitySyncService(
      dataSource: device,
      repository: cloud,
      currentUserId: () => uid,
      clock: () => now,
      cloudAckTimeout: ack,
      readTimeout: const Duration(milliseconds: 50),
    );
  }

  setUp(() {
    device = FakeDataSource();
    cloud = FakeActivityRepository();
    uid = 'user-a';
    now = DateTime(2026, 10, 14, 15, 0);
  });

  test('publishes the capture locally and confirms the cloud write', () async {
    final service = build();
    final result = await service.syncNow(force: true);

    expect(result.state, ActivitySyncState.partialData); // movement: noSamples
    expect(service.today.value!.log.appUsageMinutes, 45);
    expect(service.today.value!.apps.first.appName, 'Vivora');
    expect(service.cloudStatus.value.state, CloudSyncState.synced);
    expect(cloud.writes, 1);
  });

  test(
    'offline: data stays visible and the status is pending, then synced',
    () async {
      cloud.writeGate = Completer<void>();
      final service = build();

      await service.syncNow(force: true);

      expect(
        service.today.value,
        isNotNull,
        reason: 'local data must not depend on the network',
      );
      expect(service.cloudStatus.value.state, CloudSyncState.pendingOffline);

      cloud.writeGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(service.cloudStatus.value.state, CloudSyncState.synced);
    },
  );

  test(
    'permission and auth failures are reported distinctly from network ones',
    () async {
      cloud.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final service = build();
      await service.syncNow(force: true);
      expect(service.cloudStatus.value.state, CloudSyncState.permissionDenied);

      cloud.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
      );
      await service.syncNow(force: true);
      expect(service.cloudStatus.value.state, CloudSyncState.unauthenticated);

      cloud.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await service.syncNow(force: true);
      expect(service.cloudStatus.value.state, CloudSyncState.pendingOffline);
    },
  );

  test('repeated syncs replace the day instead of adding to it', () async {
    final service = build();
    await service.syncNow(force: true);
    await service.syncNow(force: true);
    await service.syncNow(force: true);

    final stored = cloud.logs.values.single;
    expect(stored.appUsageMinutes, 45);
    final apps = await cloud.getDailyAppUsage(
      uid: 'user-a',
      date: now,
      captureId: stored.captureId,
    );
    expect(apps.length, 3);
    expect(
      apps
          .firstWhere((a) => a.packageName == 'com.whatsapp')
          .foregroundDuration,
      const Duration(minutes: 6),
    );
  });

  test(
    'an app that disappears from the device report is hidden, not kept stale',
    () async {
      // First capture includes a stale aggregate-style entry (the old Katana bug).
      device.apps = <AppUsageEntry>[
        ...device.apps,
        app('com.facebook.katana', 'Facebook', const Duration(minutes: 75)),
      ];
      final service = build();
      await service.syncNow(force: true);

      device.apps = device.apps
          .where((a) => a.packageName != 'com.facebook.katana')
          .toList();
      now = now.add(const Duration(minutes: 1));
      await service.syncNow(force: true);

      final stored = cloud.logs.values.single;
      final apps = await cloud.getDailyAppUsage(
        uid: 'user-a',
        date: now,
        captureId: stored.captureId,
      );
      expect(
        apps.map((a) => a.packageName),
        isNot(contains('com.facebook.katana')),
      );
    },
  );

  test('automatic syncs are throttled; forced syncs are not', () async {
    final service = build();
    await service.syncIfNeeded();
    await service.syncIfNeeded();
    expect(device.captureCalls, 1);

    await service.syncNow(force: true);
    expect(device.captureCalls, 2);

    now = now.add(
      ActivitySyncService.throttleWindow + const Duration(seconds: 1),
    );
    await service.syncIfNeeded();
    expect(device.captureCalls, 3);
  });

  test('concurrent sync requests share one capture', () async {
    final service = build();
    final results = await Future.wait(<Future<ActivitySyncResult>>[
      service.syncNow(force: true),
      service.syncNow(force: true),
    ]);
    expect(device.captureCalls, 1);
    expect(identical(results[0], results[1]), isTrue);
  });

  test('without Usage Access nothing is captured or invented', () async {
    device.permissions = const ActivityPermissionSnapshot(
      usageAccessGranted: false,
      activityPermissionGranted: false,
      notificationPermissionGranted: false,
      backgroundSyncEnabled: false,
    );
    final service = build();
    final result = await service.syncNow(force: true);

    expect(result.state, ActivitySyncState.permissionRequired);
    expect(device.captureCalls, 0);
    expect(service.today.value, isNull);
  });

  test('signed out: no capture and a clear message', () async {
    uid = null;
    final service = build();
    final result = await service.syncNow(force: true);
    expect(result.state, ActivitySyncState.failed);
    expect(device.captureCalls, 0);
  });

  test('switching account clears the previous user\'s data', () async {
    final service = build();
    await service.syncNow(force: true);
    expect(service.today.value, isNotNull);

    service.onUserChanged('user-b');
    expect(service.today.value, isNull);
    expect(service.cloudStatus.value.state, CloudSyncState.idle);
  });

  test(
    'user category overrides win over defaults and survive resync',
    () async {
      cloud.overrides = <String, AppCategory>{
        'com.google.android.youtube': AppCategory.productive,
      };
      final service = build();
      await service.syncNow(force: true);

      final youtube = service.today.value!.apps.firstWhere(
        (a) => a.packageName == 'com.google.android.youtube',
      );
      expect(youtube.category, AppCategory.productive);
      expect(youtube.categoryIsUserOverride, isTrue);
      // Unknown apps are not assumed distracting.
      final whatsapp = service.today.value!.apps.firstWhere(
        (a) => a.packageName == 'com.whatsapp',
      );
      expect(whatsapp.category, isNot(AppCategory.distracting));

      await service.setCategoryOverride(
        'com.whatsapp',
        AppCategory.distracting,
      );
      await service.syncNow(force: true);
      expect(
        service.today.value!.apps
            .firstWhere((a) => a.packageName == 'com.whatsapp')
            .category,
        AppCategory.distracting,
      );
      expect(service.today.value!.log.distractingAppMinutes, 6);
    },
  );

  test('category totals are summed from exact durations', () {
    final log = ActivitySyncService.buildDailyLog(
      capture: ActivityCaptureSnapshot(
        start: now,
        end: now,
        usagePermissionGranted: true,
        activityPermissionGranted: true,
        notificationPermissionGranted: true,
        syncStatus: ActivitySyncState.success,
        appUsageEntries: const <AppUsageEntry>[],
      ),
      apps: <AppUsageEntry>[
        // Three 40-second apps: per-app rounding would give 3 × 1 = 3 minutes.
        for (int i = 0; i < 3; i++)
          app(
            'p$i',
            'App $i',
            const Duration(seconds: 40),
            category: AppCategory.distracting,
          ),
      ],
      date: now,
      captureId: '1',
      syncedAt: now,
    );
    expect(log.distractingAppMinutes, 2);
    expect(log.productiveAppMinutes, 0);
  });
}
