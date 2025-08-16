import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz; // <-- Importer timezone
import 'firebase_options.dart';
import 'screens/admin_login_screen.dart';
import 'screens/animated_loading_screen.dart';
import 'services/notification_service.dart';

void main() async {
  // Assure que les bindings Flutter sont prêts
  WidgetsFlutterBinding.ensureInitialized();

  // **NOUVEAU : Initialise la base de données des fuseaux horaires**
  tz.initializeTimeZones();

  // Initialise Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialise notre service de notification
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SosElectricityadmin',
      home: AnimatedLoadingScreen(
        nextScreen: AdminLoginScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}