import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'screens/admin_login_screen.dart';
import 'screens/animated_loading_screen.dart';
import 'services/notification_service.dart';
// **** NOUVEL IMPORT ****
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialise le service de notification
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions(); // Demande de permissions ici

  // **** INITIALISE LE SERVICE D'ARRIÈRE-PLAN ****
  await initializeService();

  // On stocke l'information que c'est bien l'app admin
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isAdmin', true);
  // Un ID fixe pour l'admin, car il n'y a pas de connexion Firebase Auth
  await prefs.setString('userId', 'admin_user_id');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SosElectricity Admin',
      home: AnimatedLoadingScreen(
        nextScreen: AdminLoginScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}