import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Backend configuration.
///
/// The URL and publishable key are designed to ship inside client apps; access is
/// enforced by Row Level Security in the database. NEVER put a service_role / secret
/// key here.
///
/// Override per build with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xwdaygcezdbneoubimgv.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_WuaXdMyoYL23EcSjOgGdNQ_Q8v_J4cq',
  );

  // Firebase, for push notifications. These values only identify the app to
  // Firebase and are public by design (like the publishable key above); they come
  // from the Firebase console. Empty = push is off and only the in-app list works.
  // NEVER put the Firebase service account key here: that one lives only in
  // Supabase (Edge Functions > Secrets).
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '');
  static const firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: '');
  static const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
  static const firebaseWebApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
  static const firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '');
  static const firebaseVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY', defaultValue: '');

  static bool get pushConfigured =>
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      (kIsWeb ? firebaseWebApiKey.isNotEmpty : firebaseAndroidApiKey.isNotEmpty && firebaseAndroidAppId.isNotEmpty);

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: kIsWeb ? firebaseWebApiKey : firebaseAndroidApiKey,
        appId: kIsWeb ? firebaseWebAppId : firebaseAndroidAppId,
        messagingSenderId: firebaseSenderId,
        projectId: firebaseProjectId,
      );
}
