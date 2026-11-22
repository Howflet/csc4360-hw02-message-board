import 'package:firebase_auth/firebase_auth.dart';

/// Translates raw Firebase errors into short, helpful messages for the user.
/// Showing the real `error.code` verbatim would be confusing, so this maps the
/// common cases and falls back gracefully.
String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'email-already-in-use':
        return 'That email is already registered. Try signing in instead.';
      case 'weak-password':
        return 'That password is too weak. Use at least 6 characters.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network problem. Check your connection and retry.';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }

  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Firestore denied that operation — you can only change your own posts.';
    }
    return error.message ?? 'Something went wrong.';
  }

  return error.toString();
}
