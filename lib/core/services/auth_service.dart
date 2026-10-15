import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Resolved lazily so constructing the service never requires Firebase.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();
        // Sign out immediately so they can't access the app until verified
        await _auth.signOut();
        return 'success';
      }
      return 'An error occurred during signup.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        if (!user.emailVerified) {
          await _auth.signOut();
          return 'email-not-verified';
        }
        return 'success';
      }
      return 'An error occurred during login.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        return 'invalid-email';
      } else if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        // Current Firebase projects return invalid-credential for both a wrong
        // email and a wrong password (email enumeration protection).
        return 'invalid-credentials';
      } else if (e.code == 'network-request-failed') {
        return 'No internet connection. Please try again.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sends a password-reset email. Returns 'success' or an error message.
  Future<String> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      }
      if (e.code == 'network-request-failed') return 'No internet connection.';
      return e.message ?? 'Could not send the reset email.';
    }
  }

  /// Re-sends the verification email for an unverified account. Requires the
  /// password because Firebase only sends it to a signed-in user; the user is
  /// signed out again afterwards.
  Future<String> resendVerification({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.sendEmailVerification();
      await _auth.signOut();
      return 'success';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send the verification email.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
