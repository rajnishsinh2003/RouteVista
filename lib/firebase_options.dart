// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// 
/// Note: This version returns NULL for unconfigured platforms to prevent
/// startup crashes, allowing the app to load its UI even if Firebase is missing.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      // Reverting to null because the placeholder App ID breaks Firebase Auth on Web.
      // Once you have your Web App ID, replace 'null' with 'web' below.
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return null;
      default:
        return null;
    }
  }

  // To enable Web, create a Web App in Firebase Console and replace these placeholders.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAG_A5VoQBndXxY0U1tpZJREP16XQ_gyVE',
    appId: 'REPLACE_WITH_YOUR_WEB_APP_ID',
    messagingSenderId: '325074376387',
    projectId: 'routevista-96fac',
    authDomain: 'routevista-96fac.firebaseapp.com',
    storageBucket: 'routevista-96fac.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAG_A5VoQBndXxY0U1tpZJREP16XQ_gyVE',
    appId: '1:325074376387:android:0b8c1e791de856c044b476',
    messagingSenderId: '325074376387',
    projectId: 'routevista-96fac',
    storageBucket: 'routevista-96fac.firebasestorage.app',
  );
}
