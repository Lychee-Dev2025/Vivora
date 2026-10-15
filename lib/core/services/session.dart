import 'package:firebase_auth/firebase_auth.dart';

/// Single seam for "who is signed in". Screens ask this instead of touching
/// `FirebaseAuth.instance` directly, so their layouts can be rendered in widget
/// tests (where no Firebase app exists) by overriding [currentUserId].
class Session {
  const Session._();

  static String? Function() currentUserId = () =>
      FirebaseAuth.instance.currentUser?.uid;

  static String? Function() currentEmail = () =>
      FirebaseAuth.instance.currentUser?.email;
}
