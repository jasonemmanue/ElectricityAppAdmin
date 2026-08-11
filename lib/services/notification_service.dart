import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'alert_policy.dart';

/// Channel used when an alert must NOT ring (quiet hours, or urgent alerts
/// switched off). A separate channel is required because Android freezes a
/// channel's importance and sound at creation time.
const String quietChannelId = 'admin_channel_quiet_01';

class NotificationService {
  static final NotificationService _notificationService =
  NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'admin_channel_id_01',
      'Alertes Administrateur',
      description:
      'Canal pour les notifications urgentes et les rappels.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    // Companion channel for quiet hours — no sound, default importance, so it
    // never rings. Android locks these traits at creation, hence two channels.
    const AndroidNotificationChannel quietChannel = AndroidNotificationChannel(
      quietChannelId,
      'Alertes discrètes',
      description: 'Alertes reçues pendant les heures calmes (sans sonnerie).',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(quietChannel);

    // --- MODIFICATION POUR L'ICÔNE PERSONNALISÉE ---
    // On remplace '@mipmap/ic_launcher' par 'ic_notification' pour utiliser
    // votre logo depuis le dossier android/app/src/main/res/drawable/
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    debugPrint("✅ [ADMIN] NotificationService initialisé.");
  }

  // Demande les permissions de base pour les notifications
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // Demande la permission spéciale pour les alarmes et rappels
  Future<void> requestAlarmPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  }


  /// Shows an admin alert. Whether it *rings* (full-screen intent + alarm
  /// category, which bypasses Do Not Disturb) depends on the "Alertes urgentes"
  /// switch and the quiet-hours window. Outside those, the alert still arrives
  /// — it just doesn't wake anyone up at 3 a.m.
  ///
  /// For pushes, that call has already been made server-side against this
  /// device's own clock (functions/src/alertPolicy.ts) and arrives in
  /// [serverDecided]/[fullScreen]; re-deciding here would only introduce a
  /// second, possibly contradictory answer — and it would disagree with what
  /// the system tray already did while the app was backgrounded. The local
  /// [AlertPolicy] is the fallback for everything else.
  Future<void> showFullScreenNotification(
      int id, String title, String body,
      {bool fullScreen = true, bool serverDecided = false}) async {
    final ring = serverDecided
        ? fullScreen
        : fullScreen && await AlertPolicy.shouldRingUrgently();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      // Quiet alerts go to their own channel: on Android a channel's
      // importance/sound is immutable after creation, so reusing the loud
      // channel with playSound:false would be ignored by the system.
      ring ? 'admin_channel_id_01' : quietChannelId,
      ring ? 'Alertes Administrateur' : 'Alertes discrètes',
      channelDescription: ring
          ? 'Canal pour les alertes urgentes admin.'
          : 'Alertes reçues pendant les heures calmes.',
      importance: ring ? Importance.max : Importance.defaultImportance,
      priority: ring ? Priority.high : Priority.defaultPriority,
      playSound: ring,
      sound: ring
          ? const RawResourceAndroidNotificationSound('notification_sound')
          : null,
      fullScreenIntent: ring,
      icon: 'ic_notification',
      color: const Color(0xFF1A237E),
      colorized: true,
      category: ring
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );

    if (!ring) {
      debugPrint('🔕 [ADMIN] Alerte discrète (heures calmes ou alertes '
          'urgentes désactivées, décidé par '
          '${serverDecided ? "le serveur" : "l'app"}) : $title');
    }

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledTime) async {
    debugPrint("🚀 [ADMIN] Planification du rappel #$id pour $scheduledTime");

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'admin_channel_id_01',
      'Alertes Administrateur',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      fullScreenIntent: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint("✅ [ADMIN] Rappel #$id planifié avec succès.");
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    debugPrint("🗑️ [ADMIN] Notification/Rappel #$id annulé(e).");
  }
}