// Hand-written, not `flutterfire configure`-generated (no Node/FlutterFire CLI
// in this build environment) — values pulled directly from the Firebase MCP
// tools against the real `arcane-dark-rpg` project. Android is this app's
// only shipping platform right now; other platforms intentionally throw so a
// stray build for them fails loudly instead of silently misconfiguring.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Arcane Dark yet.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('${defaultTargetPlatform.name} is not configured for Arcane Dark yet — Android is the only supported platform so far.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDys88N7Gjs0wgoc76SZ4KvUwB2UdyPglA',
    appId: '1:14259062190:android:09a5f6fe2895dd6ed8743f',
    messagingSenderId: '14259062190',
    projectId: 'arcane-dark-rpg',
    storageBucket: 'arcane-dark-rpg.firebasestorage.app',
  );
}
