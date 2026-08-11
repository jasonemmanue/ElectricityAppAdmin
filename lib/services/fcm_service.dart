// Admin FCM lifecycle: request perms, upload token to `admin_tokens/` via
// Cloud Function, handle foreground messages by re-broadcasting them on the
// high-importance admin channel (custom sound + full-screen intent).

import 'dart:io' show Platform;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'alert_policy.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> adminBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [ADMIN BG] FCM ${message.messageId}: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    debugPrint('🔔 [ADMIN] FCM permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onBackgroundMessage(adminBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ??
          (message.data['title'] as String? ?? 'SOS Electricity Admin');
      final body =
          message.notification?.body ?? (message.data['body'] as String? ?? '');
      final fullScreen = (message.data['fullScreen'] ?? 'true') == 'true';
      // Cloud Functions already evaluated this device's quiet hours against its
      // own clock and picked the channel accordingly — see sendToAdmins.
      final serverDecided = message.data['ringDecision'] == 'server';
      if (body.isEmpty) return;

      await NotificationService().showFullScreenNotification(
        message.hashCode,
        title,
        body,
        fullScreen: fullScreen,
        serverDecided: serverDecided,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      debugPrint('🚪 [ADMIN] App opened from notif: ${m.data}');
    });

    if (FirebaseAuth.instance.currentUser != null) {
      await _registerCurrentToken();
    }
    _messaging.onTokenRefresh.listen((_) async {
      _lastRegisteredToken = null;
      if (FirebaseAuth.instance.currentUser != null) {
        await _registerCurrentToken();
      }
    });
  }

  Future<void> registerAfterSignIn() async {
    await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      if (token == _lastRegisteredToken) return;
      final callable = FirebaseFunctions.instance.httpsCallable('registerFcmToken');
      await callable.call<void>({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'),
        // Ships the ring policy with the token so a new or refreshed token is
        // never briefly registered without one — the server rings by default
        // when a device has no policy, which would defeat quiet hours.
        'alertPolicy': AlertPolicy.instance.toJson(),
      });
      _lastRegisteredToken = token;
      debugPrint('✅ [ADMIN] FCM token registered: ${token.substring(0, 12)}…');
    } catch (e) {
      debugPrint('⚠️ [ADMIN] FCM token registration failed: $e');
    }
  }

  Future<void> unregisterOnSignOut() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      final callable = FirebaseFunctions.instance.httpsCallable('unregisterFcmToken');
      await callable.call<void>({'token': token});
      _lastRegisteredToken = null;
    } catch (e) {
      debugPrint('⚠️ [ADMIN] FCM unregister failed: $e');
    }
  }
}
