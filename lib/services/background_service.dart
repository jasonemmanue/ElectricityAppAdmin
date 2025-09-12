import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final NotificationService notificationService = NotificationService();
  await notificationService.init();

  // On ne gère les notifications de premier plan que sur Android
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // **** CORRECTION APPLIQUÉE ICI ****
    // La ligne a été déplacée à l'intérieur de la vérification Android
    service.setForegroundNotificationInfo(
      title: "SOS Electricity Admin",
      content: "Service de surveillance actif.",
    );
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  debugPrint("✅ [ADMIN] Le service d'arrière-plan a démarré.");

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    debugPrint("⏰ [ADMIN] Le minuteur s'est déclenché. Vérification de l'activité des clients...");
    await checkForAdminNotifications(notificationService);
  });
}

Future<void> checkForAdminNotifications(NotificationService notificationService) async {
  final firestore = FirebaseFirestore.instance;
  final prefs = await SharedPreferences.getInstance();

  try {
    final lastCheckKey = 'admin_last_check';
    final lastCheckMillis = prefs.getInt(lastCheckKey) ?? 0;

    Timestamp lastCheckTimestamp;
    if (lastCheckMillis == 0) {
      lastCheckTimestamp = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1)));
    } else {
      lastCheckTimestamp = Timestamp.fromMillisecondsSinceEpoch(lastCheckMillis);
    }

    debugPrint("   [ADMIN] Recherche de l'activité depuis $lastCheckTimestamp...");

    final querySnapshot = await firestore
        .collection('chats')
        .where('lastMessageAt', isGreaterThan: lastCheckTimestamp)
        .get();

    debugPrint("   [ADMIN] ${querySnapshot.docs.length} conversation(s) avec une nouvelle activité trouvée(s).");

    if (querySnapshot.docs.isEmpty) {
      await prefs.setInt(lastCheckKey, Timestamp.now().millisecondsSinceEpoch);
      return;
    }

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final userEmail = data['userEmail'] ?? 'Un utilisateur';
      final userId = data['userId'];
      final lastMessageTimestamp = data['lastMessageAt'] as Timestamp;
      final notifiedKey = 'notified_admin_${doc.id}_${lastMessageTimestamp.millisecondsSinceEpoch}';

      if (!(prefs.getBool(notifiedKey) ?? false)) {
        bool hasNewAppointment = (data['unreadAppointmentCountAdmin'] ?? 0) > 0;
        bool hasNewMessage = (data['unreadChatCountAdmin'] ?? 0) > 0;

        String? notificationTitle;
        String? notificationBody;
        int? notificationId;

        if (hasNewAppointment) {
          debugPrint("   [ADMIN] 🎉 NOUVEAU RDV de $userEmail ! Préparation de la notification...");
          notificationTitle = 'Nouveau Rendez-vous';
          notificationBody = '$userEmail a soumis une nouvelle demande de rendez-vous.';
          notificationId = 'new_appt_$userId'.hashCode;
        } else if (hasNewMessage) {
          debugPrint("   [ADMIN] 🎉 NOUVEAU MESSAGE de $userEmail ! Préparation de la notification...");
          notificationTitle = 'Nouveau Message Client';
          notificationBody = 'Vous avez un nouveau message de $userEmail.';
          notificationId = 'new_chat_$userId'.hashCode;
        }

        if (notificationTitle != null && notificationBody != null && notificationId != null) {
          await notificationService.showFullScreenNotification(
            notificationId,
            notificationTitle,
            notificationBody,
          );
          await prefs.setBool(notifiedKey, true);
        } else {
          debugPrint("   [ADMIN] Activité trouvée pour $userEmail, mais les compteurs non-lus sont à zéro. On ignore.");
        }
      } else {
        debugPrint("   [ADMIN] Activité de $userEmail déjà notifiée (Clé: $notifiedKey). On ignore.");
      }
    }

    await prefs.setInt(lastCheckKey, Timestamp.now().millisecondsSinceEpoch);

  } catch (e) {
    debugPrint("   [ADMIN] ❌ ERREUR lors de la vérification : $e");
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'admin_foreground_service',
    'SOS Electricity Admin Service',
    description: 'Ce service surveille activement les nouvelles demandes des clients.',
    importance: Importance.low,
  );

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'admin_foreground_service',
      initialNotificationTitle: 'SOS Electricity Admin',
      initialNotificationContent: 'Le service de surveillance démarre...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

