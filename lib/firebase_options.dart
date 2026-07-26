import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Native Firebase options are read from google-services.json or GoogleService-Info.plist.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDmINDRHAwFYipLUys_Y7OYMEfPud8-FeI',
    appId: '1:891432357321:web:6d3baed44fa3bb77dbac18',
    messagingSenderId: '891432357321',
    projectId: 'briefai-germany',
    authDomain: 'briefai-germany.firebaseapp.com',
    storageBucket: 'briefai-germany.firebasestorage.app',
  );
}
