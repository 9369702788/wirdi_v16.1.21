// File generated from google-services.json
// Equivalent to what `flutterfire configure` produces.
// DO NOT commit this file to a public repository.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android; // fallback
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyD1aBMMUtgG6gZyi42Qh8vynTymUzWtMtw',
    appId:             '1:820417111781:android:e616b3a50dc9363d69560c',
    messagingSenderId: '820417111781',
    projectId:         'wirdi-cd6c0',
    storageBucket:     'wirdi-cd6c0.firebasestorage.app',
  );

  // iOS options — fill in after running `flutterfire configure` on a Mac
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyD1aBMMUtgG6gZyi42Qh8vynTymUzWtMtw',
    appId:             '1:820417111781:android:e616b3a50dc9363d69560c',
    messagingSenderId: '820417111781',
    projectId:         'wirdi-cd6c0',
    storageBucket:     'wirdi-cd6c0.firebasestorage.app',
    iosClientId:       '', // add from GoogleService-Info.plist
    iosBundleId:       'com.wirdi.wirdi',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyD1aBMMUtgG6gZyi42Qh8vynTymUzWtMtw',
    appId:             '1:820417111781:android:e616b3a50dc9363d69560c',
    messagingSenderId: '820417111781',
    projectId:         'wirdi-cd6c0',
    storageBucket:     'wirdi-cd6c0.firebasestorage.app',
    authDomain:        'wirdi-cd6c0.firebaseapp.com',
  );
}
