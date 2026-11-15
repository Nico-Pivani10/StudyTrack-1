import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return android;
      default:
        throw UnsupportedError('Esta plataforma todavía no está configurada.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuN-HcXIIntF6n9ZnulJ57kEewXPxRpeQ',
    appId: '1:306413881045:web:efcb6fbc881a801709445c',
    messagingSenderId: '306413881045',
    projectId: 'studytrack-1ea89',
    authDomain: 'studytrack-1ea89.firebaseapp.com',
    storageBucket: 'studytrack-1ea89.firebasestorage.app',
    measurementId: 'G-TTK8E606QW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFGBOuw_7CTHPHq91GKTMsAUa4LEdJd0E',
    appId: '1:306413881045:android:afe1f606c657592309445c',
    messagingSenderId: '306413881045',
    projectId: 'studytrack-1ea89',
    storageBucket: 'studytrack-1ea89.firebasestorage.app',
  );
}
