import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Real Firebase Authentication — anonymous (default, no-account solo play),
/// Google Sign-In, and Email/Password. Solo play never requires signing in;
/// this is only used when the player opts into multiplayer or cloud sync.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Called once at app startup / first multiplayer action so there is always
  /// a stable uid to key Firestore documents on, even before the player picks
  /// a real sign-in method.
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  Future<User> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) throw AuthException('CANCELLED', 'Sign-in was cancelled.');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final existing = _auth.currentUser;
    if (existing != null && existing.isAnonymous) {
      // Upgrade the anonymous account so any local session/character data tied
      // to this uid carries over instead of starting a fresh, empty account.
      final result = await existing.linkWithCredential(credential);
      return result.user!;
    }
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<User> registerWithEmail(String email, String password) async {
    final existing = _auth.currentUser;
    final credential = EmailAuthProvider.credential(email: email, password: password);
    if (existing != null && existing.isAnonymous) {
      final result = await existing.linkWithCredential(credential);
      return result.user!;
    }
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return result.user!;
  }

  Future<User> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user!;
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  /// Permanently deletes the current user's Firebase Auth account and all associated cloud data.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Delete cloud-synced character documents from Firestore if present
    try {
      final charsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('characters')
          .get();
      for (final doc in charsSnapshot.docs) {
        await doc.reference.delete();
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    } catch (_) {
      // Continue even if Firestore records don't exist
    }

    // 2. Disconnect Google Sign-In if active
    try {
      await _google.signOut();
    } catch (_) {}

    // 3. Delete Firebase Auth user record
    await user.delete();

    // 4. Re-sign in anonymously so the app returns cleanly to default offline guest state
    await _auth.signInAnonymously();
  }

  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' => 'No account found with that email.',
        'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
        'email-already-in-use' => 'An account already exists with that email — try signing in instead.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'network-request-failed' => 'No internet connection.',
        'credential-already-in-use' => 'That Google account is already linked to a different Arcane Dark account.',
        'requires-recent-login' => 'This sensitive operation requires a recent login. Please sign in again before deleting your account.',
        _ => e.message ?? 'Something went wrong — please try again.',
      };
    }
    if (e is AuthException) return e.message;
    return 'Something went wrong — please try again.';
  }
}

class AuthException implements Exception {
  final String code;
  final String message;
  AuthException(this.code, this.message);
}
