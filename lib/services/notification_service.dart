import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'main_channel_fullscreen_v1', // Nouvel ID pour forcer la mise à jour
      'Rappels Critiques', // Nouveau nom, plus explicite
      description: 'Canal pour les rappels de rendez-vous critiques.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);


    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      // ...
    } else if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

      var status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  }

  Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledTime) async {

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel_fullscreen_v1', // Utiliser le nouvel ID de canal
      'Rappels Critiques',
      channelDescription: 'Canal pour les rappels de rendez-vous critiques.',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
      // **AJOUT DE LA LIGNE LA PLUS IMPORTANTE**
      fullScreenIntent: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}