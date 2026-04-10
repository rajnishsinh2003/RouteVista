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
      // Use null to signal that Web is not currently configured.
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return null; // Signals iOS is not currently configured.
      default:
        // Returns null for any other platform to avoid the "Options cannot be null" crash.
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAG_A5VoQBndXxY0U1tpZJREP16XQ_gyVE',
    appId: '1:325074376387:android:e14bcfe1adc4919544b476',
    messagingSenderId: '325074376387',
    projectId: 'routevista-96fac',
    storageBucket: 'routevista-96fac.firebasestorage.app',
  );
}
