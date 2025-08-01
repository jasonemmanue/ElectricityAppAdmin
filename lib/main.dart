import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // <-- Le fichier qui vient d'être créé
import 'screens/admin_login_screen.dart'; // Votre page de connexion admin

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // Utilise les identifiants générés par la CLI
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Admin SOS Electricity',
      home: AdminLoginScreen(), // Démarrer sur la page de connexion
    );
  }
}