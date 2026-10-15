import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_date_utils.dart';
import '../models/app_usage_entry.dart';
import '../models/daily_activity_log.dart';

/// Firestore access for automatically collected activity.
///
/// Schema (all under the signed-in user's own document):
///  * `users/{uid}/activityLogs/{yyyy_MM_dd}`: one [DailyActivityLog] per day;
///  * `users/{uid}/activityLogs/{yyyy_MM_dd}/appUsage/{package}`: per-app usage;
///  * `users/{uid}/settings/appCategories`: `{packageName: category}` chosen by
///    the user, applied to every day.
///
/// Each capture recomputes the whole day from the device, so a write *replaces*
/// that day's values rather than adding to them: repeated syncs cannot inflate
/// totals. The day document and all of its app documents are written in one
/// atomic batch tagged with the same `captureId`; app documents left over from
/// an older capture (e.g. the stale 75-minute "Katana" entry) keep their old id
/// and are ignored on read. Nothing is deleted.
class ActivityRepository {
  ActivityRepository({FirebaseFirestore? firestore})
    : _providedFirestore = firestore;

  final FirebaseFirestore? _providedFirestore;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _activityLogs(String uid) {
    return _firestore.collection('users').doc(uid).collection('activityLogs');
  }

  DocumentReference<Map<String, dynamic>> _categoryOverridesDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('appCategories');
  }

  Future<DailyActivityLog?> getDailyActivityLog({
    required String uid,
    required DateTime date,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _activityLogs(
      uid,
    ).doc(ActivityDateUtils.documentIdFor(date)).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return DailyActivityLog.fromMap(data, documentId: snapshot.id);
  }

  /// Logs for the last [days] local days (including today), oldest first.
  /// Document ids are `yyyy_MM_dd`, so a document-id range query is exact
  /// regardless of how older builds stored the `date` field.
  Future<List<DailyActivityLog>> getActivityLogsForLastDays({
    required String uid,
    required int days,
    DateTime? today,
  }) async {
    final List<DateTime> range = ActivityDateUtils.lastDays(
      today ?? DateTime.now(),
      days,
    );
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _activityLogs(uid)
            .where(
              FieldPath.documentId,
              isGreaterThanOrEqualTo: ActivityDateUtils.documentIdFor(
                range.first,
              ),
            )
            .where(
              FieldPath.documentId,
              isLessThanOrEqualTo: ActivityDateUtils.documentIdFor(range.last),
            )
            .get();
    final List<DailyActivityLog> logs =
        snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  DailyActivityLog.fromMap(doc.data(), documentId: doc.id),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  /// App usage for one day, restricted to the capture recorded in the day log.
  Future<List<AppUsageEntry>> getDailyAppUsage({
    required String uid,
    required DateTime date,
    String? captureId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _activityLogs(
      uid,
    ).doc(ActivityDateUtils.documentIdFor(date)).collection('appUsage').get();
    return filterCurrentCapture(
      snapshot.docs.map((doc) => AppUsageEntry.fromMap(doc.data())).toList(),
      captureId,
    );
  }

  /// Keeps only entries from [captureId] with real usage, longest first. When
  /// the day has no capture id (written by an older build), every entry with
  /// usage is kept, since there is no way to tell stale ones apart.
  static List<AppUsageEntry> filterCurrentCapture(
    List<AppUsageEntry> entries,
    String? captureId,
  ) {
    return entries
        .where(
          (AppUsageEntry entry) => entry.foregroundDuration > Duration.zero,
        )
        .where(
          (AppUsageEntry entry) =>
              captureId == null || entry.captureId == captureId,
        )
        .toList()
      ..sort((a, b) => b.foregroundDuration.compareTo(a.foregroundDuration));
  }

  Future<Map<String, AppCategory>> getCategoryOverrides({
    required String uid,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _categoryOverridesDoc(uid).get();
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final Map<String, AppCategory> overrides = <String, AppCategory>{};
    data.forEach((String packageName, dynamic value) {
      if (packageName == 'updatedAt') {
        return;
      }
      final AppCategory category = AppCategoryX.fromValue(value?.toString());
      if (category != AppCategory.uncategorized) {
        overrides[packageName] = category;
      }
    });
    return overrides;
  }

  /// Stores a category chosen by the user. [category] `uncategorized` clears it.
  Future<void> setCategoryOverride({
    required String uid,
    required String packageName,
    required AppCategory category,
  }) {
    return _categoryOverridesDoc(uid).set(<String, dynamic>{
      packageName: category == AppCategory.uncategorized
          ? FieldValue.delete()
          : category.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Writes the day and its app usage atomically. The returned future
  /// completes only when the **server** acknowledges the batch; while offline it
  /// stays pending (the write is already in Firestore's local cache).
  Future<void> upsertDailyActivityLog({
    required String uid,
    required DailyActivityLog log,
    required List<AppUsageEntry> appUsageEntries,
  }) {
    final DocumentReference<Map<String, dynamic>> logRef = _activityLogs(
      uid,
    ).doc(log.documentId);
    final WriteBatch batch = _firestore.batch();

    final Map<String, dynamic> logData = log.toMap();
    // Explicit nulls are kept on purpose: a metric that became unavailable must
    // overwrite an older value instead of leaving it behind.
    logData['updatedAt'] = FieldValue.serverTimestamp();
    batch.set(logRef, logData, SetOptions(merge: true));

    for (final AppUsageEntry entry in appUsageEntries) {
      final Map<String, dynamic> entryData = entry
          .copyWith(captureId: log.captureId)
          .toMap();
      entryData['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(
        logRef.collection('appUsage').doc(entry.packageName),
        entryData,
        SetOptions(merge: true),
      );
    }
    return batch.commit();
  }
}
