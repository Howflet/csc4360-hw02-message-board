import 'package:firebase_auth/firebase_auth.dart';

/// Every Firebase Authentication call lives here.
///
/// Widgets never talk to `FirebaseAuth` directly — they ask this service, so
/// register, sign-in, sign-out, and auth-state reads all go through one
/// awaited, tested method each.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The stream the app's routing depends on. It emits a [User] on sign-in
  /// and null on sign-out, so the AuthGate can swap screens automatically.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  /// Creates a new email + password account. Returns the credential so the
  /// caller can write the Firestore user record for the new uid.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs an existing user in.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
