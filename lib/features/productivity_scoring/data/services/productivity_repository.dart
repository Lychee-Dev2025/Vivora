import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../activity_monitoring/data/models/activity_date_utils.dart';
import '../models/productivity_models.dart';

/// Outcome of a save, distinguishing "acknowledged by the server" from
/// "stored locally and queued" (offline).
enum SaveOutcome { synced, pendingOffline }

/// `users/{uid}/dailyLogs/{yyyy-MM-dd}`: one document per local day holding the
/// inputs and the computed score. Saving the same day again overwrites it, so
/// the dashboard, analytics and reports all read the same single record.
class ProductivityRepository {
  ProductivityRepository({FirebaseFirestore? firestore})
    : _providedFirestore = firestore;

  final FirebaseFirestore? _providedFirestore;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  /// Incremented after every local save so open screens (kept alive by the
  /// bottom navigation) reload instead of showing stale scores.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const Duration ackTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _dailyLogs(String uid) =>
      _firestore.collection('users').doc(uid).collection('dailyLogs');

  Future<SaveOutcome> saveDailyLog({
    required String uid,
    required DailyProductivityLog log,
    required ProductivityScoreResult result,
  }) async {
    final WriteBatch batch = _firestore.batch();
    batch.set(_dailyLogs(uid).doc(log.dayKey), <String, dynamic>{
      ...log.toMap(),
      ...result.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // set+merge (not update) so the first save works even if the profile
    // document does not exist yet.
    batch.set(_firestore.collection('users').doc(uid), <String, dynamic>{
      'latestProductivityScore': result.overallScore,
      'latestPerformanceLevel': result.performanceLevel,
      'latestScoreDate': log.dayKey,
      'lastScoredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final Future<void> commit = batch.commit();
    // The write is applied to the local cache immediately, so readers see it
    // even before the server acknowledges.
    revision.value++;
    try {
      await commit.timeout(ackTimeout);
      return SaveOutcome.synced;
    } on TimeoutException {
      unawaited(
        commit.catchError((Object error) {
          debugPrint('Queued productivity log failed to upload: $error');
        }),
      );
      return SaveOutcome.pendingOffline;
    }
  }

  Future<SavedDailyScore?> getDailyScore(String uid, DateTime date) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _dailyLogs(
      uid,
    ).doc(ActivityDateUtils.dayKey(date)).get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return null;
    }
    return SavedDailyScore.fromMap(data, documentId: doc.id);
  }

  Future<DailyProductivityLog?> getDailyLog(String uid, DateTime date) async {
    return (await getDailyScore(uid, date))?.log;
  }

  /// Saved days within the last [days] local days (today included), oldest
  /// first. Days without a log are simply absent: nothing is invented.
  Future<List<SavedDailyScore>> getScoresForLastDays(
    String uid, {
    required int days,
    DateTime? today,
  }) async {
    final List<DateTime> range = ActivityDateUtils.lastDays(
      today ?? DateTime.now(),
      days,
    );
    final QuerySnapshot<Map<String, dynamic>> query = await _dailyLogs(uid)
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: ActivityDateUtils.dayKey(range.first),
        )
        .where(
          FieldPath.documentId,
          isLessThanOrEqualTo: ActivityDateUtils.dayKey(range.last),
        )
        .get();
    return query.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              SavedDailyScore.fromMap(doc.data(), documentId: doc.id),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
