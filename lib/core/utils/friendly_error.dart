import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Turns an exception into a short message for users. The technical detail is
/// logged, not shown.
String friendlyError(Object error, {String action = 'complete that'}) {
  debugPrint('[$action] $error');
  if (error is TimeoutException) {
    return 'The connection is slow or offline. Your data is kept on this phone; please try again.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'You appear to be offline. Please check your connection and try again.';
      case 'permission-denied':
        return 'Vivora is not allowed to access this data. Please sign in again.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'not-found':
        return 'This information could not be found.';
    }
  }
  return 'Could not $action. Please try again.';
}
