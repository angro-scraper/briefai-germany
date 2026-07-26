// This placeholder keeps the public repository buildable before a Firebase
// project is selected. Run `flutterfire configure` before any production build;
// it replaces this file with generated, project-specific options.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Native Firebase options are read from google-services.json or GoogleService-Info.plist.',
    );
  }

  // Public web configuration is supplied by `flutterfire configure` in a real
  // deployment. Empty placeholder values deliberately make initialization fail
  // closed until that configuration exists.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_WEB_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET'),
  );
}
