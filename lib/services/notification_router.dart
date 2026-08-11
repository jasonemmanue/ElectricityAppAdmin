import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/client_details_screen.dart';

/// Turns a tapped notification into a screen.
///
/// Every alert the admin receives carries a `type` in its FCM data payload
/// (see functions/src/triggers.ts), and local reminders carry the same shape as
/// a JSON payload. This maps those onto the app's navigation.
///
/// Taps arrive in three different situations, and all three funnel through
/// [handle]:
///  * app in the foreground — the local notification's tap callback;
///  * app in the background — `FirebaseMessaging.onMessageOpenedApp`;
///  * app not running at all — `getInitialMessage()` at startup, which fires
///    long before the admin has logged in and before any Navigator exists.
///
/// That last case is why [_pending] exists: routing is deferred until the shell
/// is actually on screen rather than dropped.
class NotificationRouter {
  NotificationRouter._();

  /// Attached to the root MaterialApp so pushes work without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Tab HomeShell should be showing. HomeShell listens to this.
  /// 0 = Tableau, 1 = RDV, 2 = Clients, 3 = Réglages.
  static final ValueNotifier<int> requestedTab = ValueNotifier<int>(0);

  static Map<String, dynamic>? _pending;

  /// True once the shell is mounted and able to navigate.
  static bool _ready = false;

  /// Called by HomeShell once it is on screen. Replays a tap that arrived while
  /// the app was still starting up or sitting on the login screen.
  static void onShellReady() {
    _ready = true;
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    handle(pending);
  }

  /// Called when the admin signs out — a pending route from the previous
  /// session must not fire into the next one.
  static void reset() {
    _ready = false;
    _pending = null;
  }

  /// Entry point for a tapped notification. [data] is the FCM data map, or the
  /// decoded payload of a local notification.
  static Future<void> handle(Map<String, dynamic> data) async {
    if (!_ready || navigatorKey.currentState == null) {
      _pending = data;
      return;
    }

    final type = data['type'] as String? ?? '';
    final userId = data['userId'] as String? ?? '';

    switch (type) {
      case 'appointment_created':
      case 'appointment_updated':
        requestedTab.value = 1; // RDV
        break;

      case 'chat':
        // Straight to that client's conversation.
        await _openClient(userId, initialTab: 1);
        break;

      case 'reminder':
        // The reminder names an appointment: open the client on their RDV tab.
        await _openClient(userId, initialTab: 0);
        break;

      case 'quote_created':
        // No quotes screen exists yet; the dashboard is where they surface.
        requestedTab.value = 0;
        break;

      default:
        requestedTab.value = 0;
    }
  }

  /// Decode the payload carried by a local notification.
  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Encode a data map for a local notification's payload.
  static String encodePayload(Map<String, dynamic> data) => jsonEncode(data);

  /// Push a client's detail screen. The email is not in the push payload, so it
  /// is read from Firestore; the screen only uses it for its title, so a lookup
  /// failure degrades to an empty header rather than a failed navigation.
  static Future<void> _openClient(String userId, {required int initialTab}) async {
    if (userId.isEmpty) {
      requestedTab.value = 2; // Clients — better than going nowhere.
      return;
    }

    String email = '';
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      email = (snap.data()?['email'] as String?) ??
          (snap.data()?['fullName'] as String?) ??
          '';
    } catch (_) {
      // Offline or rules issue — push anyway, the screen loads its own data.
    }

    requestedTab.value = 2; // Keep the Clients tab behind the pushed screen.
    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ClientDetailsScreen(
          userId: userId,
          userEmail: email,
          initialTab: initialTab,
        ),
      ),
    );
  }
}
