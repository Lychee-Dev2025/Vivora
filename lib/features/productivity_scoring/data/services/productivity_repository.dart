import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/productivity_models.dart';

class ProductivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveDailyLog({
    required String uid,
    required DailyProductivityLog log,
    required ProductivityScoreResult result,
  }) async {
    final dateStr = "${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}";
    
    final batch = _firestore.batch();
    
    // 1. Save to dailyLogs subcollection
    final logRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateStr);
    
    final data = {
      ...log.toMap(),
      ...result.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    batch.set(logRef, data, SetOptions(merge: true));
    
    // 2. Update latest score in user document
    final userRef = _firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'latestProductivityScore': result.overallScore,
      'latestPerformanceLevel': result.performanceLevel,
      'lastScoredAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  Future<DailyProductivityLog?> getDailyLog(String uid, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateStr)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return DailyProductivityLog.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getWeeklyLogs(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('date', descending: true)
        .get();
    
    return query.docs.map((doc) => doc.data()).toList();
  }
}
