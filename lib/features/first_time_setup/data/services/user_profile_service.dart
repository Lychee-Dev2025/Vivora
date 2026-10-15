import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';

class UserProfileService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Updates only the goals map, leaving the rest of the profile untouched.
  /// Returns once the change is in the local cache (uploads when online).
  Future<void> updateGoals(String uid, UserGoals goals) async {
    final Future<void> write = _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'goals': goals.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    try {
      await write.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      unawaited(write.catchError((Object _) {}));
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<bool> isSetupCompleted(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()?['setupCompleted'] ?? false;
    }
    return false;
  }

  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
      return null;
    });
  }
}
