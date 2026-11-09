import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../app/config/env.dart';

enum PushStatus { unavailable, blocked, on }

/// A push message, either received while the app is open or tapped in the
/// phone's notification list.
class PushMessage {
  final String title;
  final String body;
  final String? eventId;
  final bool opened; // true = the user tapped it
  final String? kind; // e.g. 'review_prompt'

  const PushMessage({required this.title, required this.body, required this.eventId, required this.opened, this.kind});
}

/// Connects the app to Firebase Cloud Messaging. Without Firebase settings in
/// [Env] (or on platforms without push) everything here quietly does nothing and
/// the in-app notification list still works.
class PushService {
  PushStatus _status = PushStatus.unavailable;
  String? _token;
  bool _listening = false;
  final _messages = StreamController<PushMessage>.broadcast();
  StreamSubscription<String>? _refreshSub;

  PushStatus get status => _status;
  Stream<PushMessage> get messages => _messages.stream;

  static bool get supportedHere =>
      Env.pushConfigured && (kIsWeb ? Env.firebaseWebAppId.isNotEmpty : defaultTargetPlatform == TargetPlatform.android);

  static String get platformName => kIsWeb ? 'web' : 'android';

  /// Asks for permission (once; the phone remembers the answer), gets this
  /// device's address and hands it to [register]. Safe to call on every sign-in.
  Future<PushStatus> start(Future<void> Function(String token) register) async {
    if (!supportedHere) return _status = PushStatus.unavailable;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: Env.firebaseOptions);
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return _status = PushStatus.blocked;
      _listen(messaging);
      final token = await messaging.getToken(vapidKey: kIsWeb ? Env.firebaseVapidKey : null);
      if (token == null) return _status = PushStatus.unavailable;
      _token = token;
      await register(token);
      _refreshSub ??= messaging.onTokenRefresh.listen((t) {
        _token = t;
        register(t).catchError((_) {});
      });
      return _status = PushStatus.on;
    } catch (e) {
      debugPrint('push unavailable: $e');
      return _status = PushStatus.unavailable;
    }
  }

  void _listen(FirebaseMessaging messaging) {
    if (_listening) return;
    _listening = true;
    FirebaseMessaging.onMessage.listen((m) => _messages.add(_toMessage(m, opened: false)));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _messages.add(_toMessage(m, opened: true)));
    // The app was started by tapping a notification.
    messaging.getInitialMessage().then((m) {
      if (m != null) _messages.add(_toMessage(m, opened: true));
    }).catchError((_) {});
  }

  PushMessage _toMessage(RemoteMessage m, {required bool opened}) => PushMessage(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        eventId: m.data['event_id'] as String?,
        opened: opened,
        kind: m.data['kind'] as String?,
      );

  /// Called before signing out: this device stops receiving the account's messages.
  Future<void> stop(Future<void> Function(String token) unregister) async {
    final token = _token;
    if (token == null) return;
    try {
      await unregister(token).timeout(const Duration(seconds: 5));
    } catch (_) {
      // The server forgets devices that stop working anyway.
    }
  }
}
