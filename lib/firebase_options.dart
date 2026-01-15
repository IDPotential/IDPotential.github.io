// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_YYN53dprEQOFC1VWeXU2hFVJEddqKyE',
    appId: '1:583337444864:android:8e236d13d39e1f42d2fae5',
    messagingSenderId: '583337444864',
    projectId: 'id-potential',
    storageBucket: 'id-potential.firebasestorage.app',
  );
}
