// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // For Android, we normally use google-services.json, 
    // but if we want to use Dart initialization, we need keys.
    // I'll leave a placeholder or try to use common keys if valid.
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for android/ios - '
      'you can reconfigure this by running the FlutterFire CLI again.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBFkAON3s4BazPkQoz-sBJs9bIjSagJB80',
    appId: '1:583337444864:web:0d704e03712d3411d2fae5',
    messagingSenderId: '583337444864',
    projectId: 'id-potential',
    authDomain: 'id-potential.firebaseapp.com',
    storageBucket: 'id-potential.firebasestorage.app',
    measurementId: 'G-DRQMZ6C9LR',
  );
}
