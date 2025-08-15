import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/admin_login_screen.dart';
import 'screens/animated_loading_screen.dart'; // <-- 1. Importez l'écran de chargement animé

void main() async {
  // Assure que les bindings Flutter sont prêts avant d'exécuter du code natif
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase pour votre projet
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SosElectricityadmin', // Le nom de votre application

      // 2. Définissez l'écran de chargement comme page d'accueil.
      // Il s'occupera de naviguer vers AdminLoginScreen après l'animation.
      home: AnimatedLoadingScreen(
        nextScreen: AdminLoginScreen(),
      ),

      debugShowCheckedModeBanner: false,
    );
  }
}