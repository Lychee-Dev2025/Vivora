import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/widgets/info_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../data/models/activity_sync_snapshot.dart';
import '../../data/models/activity_sync_state.dart';
import '../../data/models/app_usage_entry.dart';
import '../../data/models/daily_activity_log.dart';
import '../../data/services/activity_sync_service.dart';

/// Tracking status, today's device metrics and sync/cloud state.
///
/// Reads everything from [ActivitySyncService] notifiers so every screen that
/// embeds it shows the same snapshot.
class TrackingStatusCard extends StatelessWidget {
  TrackingStatusCard({super.key, ActivitySyncService? service})
    : service = service ?? ActivitySyncService.instance;

  final ActivitySyncService service;

  Listenable get _listenable => Listenable.merge(<Listenable>[
    service.syncState,
    service.permissions,
    service.today,
    service.cloudStatus,
    service.latestResult,
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _listenable,
      builder: (BuildContext context, Widget? child) => _build(context),
    );
  }

  Future<void> _enableTracking(BuildContext context) async {
    final ActivityPermissionSnapshot snapshot = await service
        .refreshPermissions();
    if (!snapshot.usageAccessGranted) {
      await service.openUsageAccessSettings();
      return;
    }
    if (!snapshot.activityPermissionGranted) {
      final bool granted = await service.requestActivityPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Physical activity permission was denied. Movement will show as unavailable.',
            ),
          ),
        );
      }
    }
    await service.syncNow(force: true);
  }

  Future<void> _syncNow(BuildContext context) async {
    final ActivitySyncResult result = await service.syncNow(force: true);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result.message} ${service.cloudStatus.value.label}.'),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final ActivitySyncState syncState = service.syncState.value;
    final ActivityPermissionSnapshot permissions = service.permissions.value;
    final TodayActivity? today = service.today.value;
    final DailyActivityLog? log = today?.log;
    final CloudSyncStatus cloud = service.cloudStatus.value;
    final bool needsUsage = !permissions.usageAccessGranted;
    final bool needsActivity = !permissions.activityPermissionGranted;
    final bool isSyncing = syncState == ActivitySyncState.syncing;
    final String? error = syncState == ActivitySyncState.failed
        ? service.latestResult.value?.message
        : null;

    final Color accent = needsUsage
        ? Colors.orange
        : syncState == ActivitySyncState.failed
        ? context.palette.danger
        : context.brand;

    return InfoCard(
      gradient: context.palette.cardGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Automatic Tracking',
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Own line: sharing the title's row squeezed the title until it
          // broke between letters ("Automati c Tracki…").
          _StatusChip(label: _statusLabel(syncState, needsUsage)),
          const SizedBox(height: 16),
          if (needsUsage) ...<Widget>[
            Text(
              'Allow Usage Access so Vivora can measure screen time and app usage on this phone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
          ],
          _TrackingRow(
            label: 'Usage Access',
            value: needsUsage ? 'Required' : 'Enabled',
          ),
          const SizedBox(height: 10),
          _TrackingRow(
            label: 'Physical Activity',
            value: needsActivity
                ? 'Not allowed'
                : permissions.backgroundSyncEnabled
                ? 'Enabled'
                : 'Allowed, not registered',
          ),
          const SizedBox(height: 10),
          _TrackingRow(
            label: 'App usage today',
            value: log?.appUsageMinutes == null
                ? 'No data yet'
                : formatMinutes(log!.appUsageMinutes!),
          ),
          const SizedBox(height: 10),
          _TrackingRow(
            label: 'Screen unlocked',
            value: log == null
                ? 'No data yet'
                : log.screenTimeMinutes == null
                ? 'Not reported by this phone'
                : formatMinutes(log.screenTimeMinutes!),
          ),
          const SizedBox(height: 10),
          _TrackingRow(
            label: 'Unlocks',
            value: log?.phoneUnlockCount?.toString() ?? 'No data yet',
          ),
          const SizedBox(height: 10),
          _TrackingRow(label: 'Top app', value: _topApp(today)),
          const SizedBox(height: 10),
          _TrackingRow(label: 'Movement', value: movementLabel(log)),
          const SizedBox(height: 10),
          _TrackingRow(
            label: 'Last device sync',
            value: _formatTime(log?.lastSyncAt),
          ),
          const SizedBox(height: 10),
          _TrackingRow(label: 'Cloud', value: cloud.label),
          if (error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: context.palette.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          if (needsUsage)
            PrimaryButton(
              label: 'Enable Usage Access',
              onPressed: () => _enableTracking(context),
              icon: Icons.security_rounded,
              isLoading: isSyncing,
            )
          else
            Row(
              children: <Widget>[
                if (needsActivity) ...<Widget>[
                  Expanded(
                    child: SecondaryButton(
                      label: 'Allow Activity',
                      onPressed: () => _enableTracking(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SecondaryButton(
                    label: isSyncing ? 'Syncing…' : 'Sync Now',
                    onPressed: isSyncing ? null : () => _syncNow(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Human-readable movement state; never shows a guessed duration.
  static String movementLabel(DailyActivityLog? log) {
    if (log == null) {
      return 'No data yet';
    }
    switch (log.movementStatus) {
      case 'permissionDenied':
        return 'Permission not granted';
      case 'notRegistered':
        return 'Not started';
      case 'noSamples':
        return 'No readings yet today';
      case 'available':
        final int active = log.activeMinutes ?? 0;
        return active > 0
            ? '${formatMinutes(active)} walking/running'
            : 'No walking detected';
      default:
        return 'Unavailable';
    }
  }

  String _topApp(TodayActivity? today) {
    if (today == null || today.apps.isEmpty) {
      return 'No app data yet';
    }
    final AppUsageEntry top = today.apps.first;
    return '${top.displayName} (${top.durationLabel})';
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return 'Never';
    }
    final DateTime local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(ActivitySyncState state, bool needsUsage) {
    if (needsUsage) {
      return 'Permission required';
    }
    switch (state) {
      case ActivitySyncState.syncing:
        return 'Syncing';
      case ActivitySyncState.failed:
        return 'Error';
      case ActivitySyncState.permissionRequired:
        return 'Permission required';
      case ActivitySyncState.idle:
        return 'Waiting';
      case ActivitySyncState.success:
      case ActivitySyncState.partialData:
        return 'Active';
    }
  }
}

class _TrackingRow extends StatelessWidget {
  const _TrackingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textTheme = Theme.of(context).textTheme;
        final isCompact = constraints.maxWidth < 340;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: textTheme.titleSmall?.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.brand,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
