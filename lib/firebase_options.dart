// File generated for project DANOV (danov-28973).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for fuchsia.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform ($defaultTargetPlatform).',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'VOTRE_API_KEY_WEB_A_RECUPERER_DANS_CONSOLES_FIREBASE',
    appId: '1:1094193363542:web:votre_app_id_web',
    messagingSenderId: '1094193363542',
    projectId: 'danov-28973',
    authDomain: 'danov-28973.firebaseapp.com',
    storageBucket: 'danov-28973.appspot.com',
    measurementId: 'G-VOTRE_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC1wZ0Ez7PZrbxv2m6FCG_Xz8Kufl18uiI',
    appId: '1:1094193363542:android:00a95591911e8ca14819f7',
    messagingSenderId: '1094193363542',
    projectId: 'danov-28973',
    storageBucket: 'danov-28973.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBx1r3esUADHtxsHt1upA7KvUxfP8O2bg0',
    appId: '1:1094193363542:ios:7b07c31011b870ff4819f7',
    messagingSenderId: '1094193363542',
    projectId: 'danov-28973',
    storageBucket: 'danov-28973.appspot.com',
    iosBundleId: 'sn.danov.alloguinaar',
  );
}