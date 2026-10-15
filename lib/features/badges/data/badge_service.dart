import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../analytics/data/analytics_calculator.dart';
import '../../insights/data/history_data.dart';
import '../../productivity_scoring/data/services/productivity_score_service.dart';

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.requirement,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;

  /// Shown under the badge so the condition is transparent.
  final String requirement;
  final IconData icon;
  final Color color;
}

/// Badges are earned only from recorded achievements. Once earned they are
/// stored in `users/{uid}/badges/{id}` with the date, so they stay unlocked even
/// after the evidence leaves the 14-day analysis window.
class BadgeService {
  BadgeService({FirebaseFirestore? firestore}) : _providedFirestore = firestore;

  final FirebaseFirestore? _providedFirestore;
  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  static List<BadgeDefinition> all = <BadgeDefinition>[
    BadgeDefinition(
      id: 'first_log',
      title: 'First Log',
      requirement: 'Save your first daily log',
      icon: Icons.edit_note_rounded,
      color: Colors.teal,
    ),
    BadgeDefinition(
      id: 'streak_3',
      title: '3-Day Streak',
      requirement: 'Log 3 days in a row',
      icon: Icons.local_fire_department_outlined,
      color: Colors.deepOrange,
    ),
    BadgeDefinition(
      id: 'streak_7',
      title: '7 Day Streak Master',
      requirement: 'Log 7 days in a row',
      icon: Icons.local_fire_department_rounded,
      color: Colors.orangeAccent,
    ),
    BadgeDefinition(
      id: 'focus_first',
      title: 'Focus Starter',
      requirement: 'Complete a full focus session',
      icon: Icons.timer_rounded,
      color: Colors.indigo,
    ),
    BadgeDefinition(
      id: 'focus_king',
      title: 'Focus King',
      requirement: 'Complete 5 focus sessions within 14 days',
      icon: Icons.star_rounded,
      color: Colors.blue,
    ),
    BadgeDefinition(
      id: 'well_rested',
      title: 'Well Rested',
      requirement: 'Meet your sleep goal on 3 logged days',
      icon: Icons.bedtime_rounded,
      color: Colors.purple,
    ),
    BadgeDefinition(
      id: 'digital_detox',
      title: 'Digital Detox Day',
      requirement: 'Finish a day within your screen-time limit (measured)',
      icon: Icons.phonelink_erase_rounded,
      color: Colors.green,
    ),
    BadgeDefinition(
      id: 'productivity_pro',
      title: 'Productivity Pro',
      requirement: 'Score 85 or more on a day',
      icon: Icons.workspace_premium_rounded,
      color: Colors.amber,
    ),
  ];

  /// Badge ids whose condition is met by [history].
  static Set<String> evaluate(HistoryData history) {
    final Set<String> earned = <String>{};
    final scored = history.scores.where((s) => s.overallScore != null).toList();
    if (scored.isNotEmpty) earned.add('first_log');
    final int streak = AnalyticsCalculator.bestStreak(scored);
    if (streak >= 3) earned.add('streak_3');
    if (streak >= 7) earned.add('streak_7');

    final int completed = history.focusSessions
        .where((s) => s.completed)
        .length;
    if (completed >= 1) earned.add('focus_first');
    if (completed >= 5) earned.add('focus_king');

    final double? sleepGoal = ProductivityScoreService.parseHours(
      history.goals?.targetSleepHours,
    );
    if (sleepGoal != null &&
        scored
                .where((s) => (s.log.actualSleepHours ?? 0) >= sleepGoal)
                .length >=
            3) {
      earned.add('well_rested');
    }

    final double? limit = ProductivityScoreService.parseHours(
      history.goals?.targetScreenTimeLimit,
    );
    if (limit != null &&
        history.completedMeasuredDays.any(
          (d) => d.appUsageMinutes! <= limit * 60,
        )) {
      earned.add('digital_detox');
    }

    if (scored.any((s) => s.overallScore! >= 85)) {
      earned.add('productivity_pro');
    }
    return earned;
  }

  /// Returns {badgeId: unlockedAt} combining stored and newly earned badges,
  /// storing the new ones.
  Future<Map<String, DateTime>> sync(String uid, HistoryData history) async {
    final CollectionReference<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('badges');
    final Map<String, DateTime> unlocked = <String, DateTime>{};
    try {
      final snapshot = await ref.get().timeout(const Duration(seconds: 8));
      for (final doc in snapshot.docs) {
        final dynamic at = doc.data()['unlockedAt'];
        unlocked[doc.id] = at is Timestamp ? at.toDate() : DateTime.now();
      }
    } catch (error) {
      debugPrint('Stored badges unavailable: $error');
    }
    final DateTime now = DateTime.now();
    for (final String id in evaluate(history)) {
      if (unlocked.containsKey(id)) continue;
      unlocked[id] = now;
      unawaited(
        ref
            .doc(id)
            .set(<String, dynamic>{
              'unlockedAt': Timestamp.fromDate(now),
              'dateKey': ActivityDateUtils.dayKey(now),
            })
            .catchError(
              (Object error) => debugPrint('Badge not stored: $error'),
            ),
      );
    }
    return unlocked;
  }
}
