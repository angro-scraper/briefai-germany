import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase is not configured for this platform.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDmINDRHAwFYipLUys_Y7OYMEfPud8-FeI',
    appId: '1:891432357321:web:6d3baed44fa3bb77dbac18',
    messagingSenderId: '891432357321',
    projectId: 'briefai-germany',
    authDomain: 'briefai-germany.firebaseapp.com',
    storageBucket: 'briefai-germany.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9VOAK3n-qc4_bFsgW4NMWt4kmujTchGM',
    appId: '1:891432357321:android:10adc4738f7f840fdbac18',
    messagingSenderId: '891432357321',
    projectId: 'briefai-germany',
    storageBucket: 'briefai-germany.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCkMErU-lGE5HnlrH30hKFMuIdhwBveGT0',
    appId: '1:891432357321:ios:ee1b65292a8b711ddbac18',
    messagingSenderId: '891432357321',
    projectId: 'briefai-germany',
    storageBucket: 'briefai-germany.firebasestorage.app',
    iosBundleId: 'com.briefai.briefaiGermany',
    iosClientId:
        '891432357321-jn75154m8kvdsotmbvvbk342g954leep.apps.googleusercontent.com',
  );
}
