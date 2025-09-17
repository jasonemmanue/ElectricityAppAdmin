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
import 'global_state.dart'; // Importez le service d'état

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final NotificationService notificationService = NotificationService();
  await notificationService.init();
  final GlobalState globalState = GlobalState();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  debugPrint("✅ [ADMIN] Le service d'arrière-plan a démarré.");

  // Écoute en temps réel des changements dans la collection 'chats'
  FirebaseFirestore.instance
      .collection('chats')
      .snapshots()
      .listen((snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    int totalUnreadConversations = 0;

    // Calcule le nombre total de conversations non lues
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if ((data['unreadChatCountAdmin'] ?? 0) > 0 ||
          (data['unreadAppointmentCountAdmin'] ?? 0) > 0) {
        totalUnreadConversations++;
      }
    }

    // Met à jour la notification persistante avec le nombre de conversations non lues
    if (service is AndroidServiceInstance) {
      if (totalUnreadConversations > 0) {
        service.setForegroundNotificationInfo(
          title: "SOS Electricity Admin",
          content: "$totalUnreadConversations conversation(s) non lue(s)",
        );
      } else {
        service.setForegroundNotificationInfo(
          title: "SOS Electricity Admin",
          content: "Aucune nouvelle notification",
        );
      }
    }

    // Traite les changements pour envoyer des notifications
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        final data = change.doc.data() as Map<String, dynamic>;
        final userEmail = data['userEmail'] ?? 'Un utilisateur';
        final userId = data['userId'];

        // Vérifie si l'admin est déjà sur l'écran de chat de cet utilisateur
        if (globalState.isAppInForeground &&
            globalState.isChatScreenActive &&
            globalState.activeChatUserId == userId) {
          debugPrint("   [ADMIN] L'admin est déjà sur le chat de $userEmail. Pas de notification.");
          continue; // Ne pas envoyer de notification
        }

        // Utilise le timestamp du dernier message pour créer une clé unique
        // et éviter de notifier plusieurs fois pour le même message.
        final lastMessageTimestamp = data['lastMessageAt'] as Timestamp;
        final notifiedKey = 'notified_admin_${change.doc.id}_${lastMessageTimestamp.millisecondsSinceEpoch}';

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
            // Marque cette notification comme envoyée
            await prefs.setBool(notifiedKey, true);
          }
        }
      }
    }
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'admin_foreground_service',
    'SOS Electricity Admin Service',
    description:
    'Ce service surveille activement les nouvelles demandes des clients.',
    importance: Importance.low,
  );

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
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