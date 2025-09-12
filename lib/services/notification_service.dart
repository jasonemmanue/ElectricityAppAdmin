import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

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
      'Canal pour les notifications urgentes (nouveaux messages/RDV).',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    debugPrint("✅ [ADMIN] NotificationService initialisé.");
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showFullScreenNotification(
      int id, String title, String body) async {
    debugPrint(
        "🚀 [ADMIN] Tentative d'affichage de la notification #$id: '$title'");

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'admin_channel_id_01',
      'Alertes Administrateur',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      fullScreenIntent: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    debugPrint("✅ [ADMIN] Notification #$id affichée avec succès.");
  }

  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledTime) async {
    debugPrint("🚀 [ADMIN] Planification du rappel #$id pour $scheduledTime");

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'admin_channel_id_01',
      'Alertes Administrateur',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
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