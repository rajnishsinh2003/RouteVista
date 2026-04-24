import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps FirebaseAuth with typed helpers.
/// 
/// Note: This version includes 'Safe Initialization' checks to avoid crashing
/// on platforms (like Web) where Firebase might not be configured.
class AuthService {
  // ── Safe Auth Instance ──────────────────────────────────────────
  // Instead of a direct field, we use a getter to avoid crashes
  // if Firebase hasn't been initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Helper to check if Firebase is available
  bool get isAvailable => Firebase.apps.isNotEmpty;

  // ── Current signed-in user ─────────────────────────────────────
  User? get currentUser => isAvailable ? _auth.currentUser : null;

  // ── Auth state stream ──────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Session helpers (SharedPreferences) ──────────────────────
  static const _kLoggedIn = 'is_logged_in';
  static const _kUserEmail = 'session_email';

  Future<void> saveSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUserEmail, email);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
    await prefs.remove(_kUserEmail);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  static Future<String> savedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmail) ?? '';
  }

  // ── Sign in ────────────────────────────────────────────────────
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await saveSession(email);
    return result;
  }

  // ── Sign in with Google ────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  // ── Register ───────────────────────────────────────────────────
  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  // ── Password reset ─────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Change password ────────────────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'No user signed in.');
    
    final email = user.email;
    if (email == null) throw FirebaseAuthException(code: 'no-email', message: 'User has no email address.');

    // Re-authenticate to ensure security for password update
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // ── Sign out ───────────────────────────────────────────────────
  Future<void> signOut() async {
    await clearSession();
    await _auth.signOut();
  }

  // ── Human-readable Firebase error messages ─────────────────────
  static String friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found for that email address.';
      case 'wrong-password': return 'Incorrect password. Please try again.';
      case 'invalid-email': return 'The email address is badly formatted.';
      case 'email-already-in-use': return 'An account already exists for this email.';
      case 'network-request-failed': return 'Network error. Please check your internet connection.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      case 'user-disabled': return 'This user account has been disabled.';
      case 'operation-not-allowed': return 'This operation is not allowed. Check Firebase settings.';
      case 'requires-recent-login': return 'Security timeout. Please sign out and sign in again to change password.';
      case 'weak-password': return 'The new password is too weak.';
      default: return 'Authentication failed: $code. Please try again.';
    }
  }
}

