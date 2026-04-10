import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Wraps FirebaseAuth with typed helpers.
/// 
/// Note: This version includes 'Safe Initialization' checks to avoid crashing
/// on platforms (like Web) where Firebase might not be configured.
class AuthService {
  // ── Safe Auth Instance ──────────────────────────────────────────
  // Instead of a direct field, we use a getter to avoid crashes
  // if Firebase hasn't been initialized.
  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        message: 'Firebase is not initialized on this platform.',
      );
    }
    return FirebaseAuth.instance;
  }

  // Helper to check if Firebase is available
  bool get isAvailable => Firebase.apps.isNotEmpty;

  // ── Current signed-in user ─────────────────────────────────────
  User? get currentUser => isAvailable ? _auth.currentUser : null;

  // ── Auth state stream ──────────────────────────────────────────
  Stream<User?> get authStateChanges {
    if (!isAvailable) {
      return Stream.value(null);
    }
    return _auth.authStateChanges();
  }

  // ── Sign in ────────────────────────────────────────────────────
  Future<dynamic> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isAvailable) {
      // Mock success for Demo Mode on Web
      debugPrint('ℹ️ Mock Login Success (Demo Mode)');
      return null; 
    }
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Register ───────────────────────────────────────────────────
  Future<dynamic> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isAvailable) {
      debugPrint('ℹ️ Mock Registration Success (Demo Mode)');
      return null;
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  // ── Password reset ─────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    if (!isAvailable) return;
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign out ───────────────────────────────────────────────────
  Future<void> signOut() async {
    if (!isAvailable) return;
    await _auth.signOut();
  }

  // ── Human-readable Firebase error messages ─────────────────────
  static String friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found for that email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'invalid-email': return 'Invalid email address.';
      case 'email-already-in-use': return 'Account already exists.';
      default: return 'Authentication failed. Please try again.';
    }
  }
}

// Simple global debugPrint if not available
void debugPrint(String s) => print(s);
