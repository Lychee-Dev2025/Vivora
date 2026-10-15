import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../activity_monitoring/data/models/activity_date_utils.dart';

class FocusSession {
  const FocusSession({
    this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedMinutes,
    required this.focusedSeconds,
    required this.completed,
  });

  final String? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedMinutes;

  /// Time actually spent focusing (pauses excluded).
  final int focusedSeconds;

  /// True when the full planned duration was reached.
  final bool completed;

  int get focusedMinutes => (focusedSeconds / 60).round();
  String get dayKey => ActivityDateUtils.dayKey(startedAt);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': Timestamp.fromDate(endedAt),
    'plannedMinutes': plannedMinutes,
    'focusedSeconds': focusedSeconds,
    'completed': completed,
    'dateKey': dayKey,
  };

  factory FocusSession.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime asDate(dynamic value) => value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    return FocusSession(
      id: id,
      startedAt: asDate(map['startedAt']),
      endedAt: asDate(map['endedAt']),
      plannedMinutes: (map['plannedMinutes'] as num?)?.toInt() ?? 0,
      focusedSeconds: (map['focusedSeconds'] as num?)?.toInt() ?? 0,
      completed: map['completed'] == true,
    );
  }
}

/// `users/{uid}/focusSessions/{autoId}`.
class FocusSessionRepository {
  FocusSessionRepository({FirebaseFirestore? firestore})
    : _providedFirestore = firestore;

  final FirebaseFirestore? _providedFirestore;
  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _firestore.collection('users').doc(uid).collection('focusSessions');

  /// Stores a finished session. Returns once it is in the local cache; the
  /// upload continues in the background when offline.
  Future<void> save(String uid, FocusSession session) async {
    final Future<void> write = _sessions(uid).doc().set(<String, dynamic>{
      ...session.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    revision.value++;
    try {
      await write.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      unawaited(
        write.catchError((Object error) {
          debugPrint('Queued focus session failed to upload: $error');
        }),
      );
    }
  }

  /// Sessions started within the last [days] local days, newest first.
  Future<List<FocusSession>> getRecent(String uid, {int days = 7}) async {
    final DateTime from = ActivityDateUtils.lastDays(
      DateTime.now(),
      days,
    ).first;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions(uid)
        .where(
          'dateKey',
          isGreaterThanOrEqualTo: ActivityDateUtils.dayKey(from),
        )
        .get();
    return snapshot.docs
        .map((doc) => FocusSession.fromMap(doc.data(), id: doc.id))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<int> focusedMinutesOn(String uid, DateTime day) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions(
      uid,
    ).where('dateKey', isEqualTo: ActivityDateUtils.dayKey(day)).get();
    final int seconds = snapshot.docs.fold<int>(
      0,
      (int sum, doc) =>
          sum + ((doc.data()['focusedSeconds'] as num?)?.toInt() ?? 0),
    );
    return (seconds / 60).round();
  }
}
