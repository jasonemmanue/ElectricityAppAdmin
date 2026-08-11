import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'alert_policy.dart';
import 'notification_router.dart';

/// Channel used when an alert must NOT ring (quiet hours, or urgent alerts
/// switched off). A separate channel is required because Android freezes a
/// channel's importance and sound at creation time.
const String quietChannelId = 'admin_channel_quiet_01';

/// Channel for scheduled appointment reminders.
///
/// These are alarms: the admin picked the instant, and expects the phone to
/// make noise then. `admin_channel_id_01` carries `USAGE_NOTIFICATION`, so its
/// sound rides the notification stream — which is why a reminder was posting
/// silently (verified on device: notification posted, `numInterrupt=0`, with
/// DND, silent mode, channel importance and permissions all ruled out).
/// `USAGE_ALARM` puts it on the alarm stream instead.
///
/// It has to be its own channel rather than a tweak to the loud one: Android
/// freezes a channel's audio attributes at creation, so changing them on an
/// existing channel is silently ignored.
const String alarmChannelId = 'admin_channel_alarm_01';

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

    // Reminders ride the alarm stream — see [alarmChannelId].
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      alarmChannelId,
      'Rappels de rendez-vous',
      description: 'Rappels programmés par l\'administrateur.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(quietChannel);
    await androidPlugin?.createNotificationChannel(alarmChannel);

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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Tapping a notification this app raised itself (foreground alerts and
      // scheduled reminders) routes through the same place as an FCM tap.
      onDidReceiveNotificationResponse: (response) {
        final data = NotificationRouter.decodePayload(response.payload);
        if (data != null) NotificationRouter.handle(data);
      },
    );
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
    if (!Platform.isAndroid) return;

    var status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Exact alarms are not enough on their own. When the alarm fires with the
    // app closed, the system has to start the process to run
    // ScheduledNotificationReceiver — and Samsung's background management
    // refuses to unless the app is exempt from battery optimisation. Observed
    // on device: the broadcast reached ActivityManager on the dot, no process
    // was ever started, and no notification was posted. Reminders only worked
    // while the app was still warm.
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// Whether this device will actually run a reminder's alarm with the app
  /// closed. False means the reminder will fire silently into the void.
  Future<bool> canFireRemindersInBackground() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
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
      {bool fullScreen = true,
      bool serverDecided = false,
      Map<String, dynamic>? data}) async {
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
      // Carries what the tap needs to open the right screen.
      payload: data == null ? null : NotificationRouter.encodePayload(data),
    );
  }

  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledTime,
      {Map<String, dynamic>? data}) async {
    debugPrint("🚀 [ADMIN] Planification du rappel #$id pour $scheduledTime");

    // Deliberately minimal: this is the exact shape that was observed posting
    // correctly on device, with the channel as the ONLY difference. The alarm
    // stream comes from the channel ([alarmChannelId]), so nothing else needs
    // to be set here — and every extra field is one more thing that can make
    // the receiver fail to rebuild the notification when it fires.
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      alarmChannelId,
      'Rappels de rendez-vous',
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
      payload: data == null ? null : NotificationRouter.encodePayload(data),
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