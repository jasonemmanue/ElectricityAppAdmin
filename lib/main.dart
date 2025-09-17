// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'screens/admin_login_screen.dart';
import 'screens/animated_loading_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/global_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();
  await notificationService.requestAlarmPermissions();

  await initializeService();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isAdmin', true);
  await prefs.setString('userId', 'admin_user_id');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalState _globalState = GlobalState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Au démarrage, l'application est considérée comme étant au premier plan.
    _globalState.setAppInForeground(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Met à jour l'état global en fonction du cycle de vie de l'application.
    final bool isAppInForeground = state == AppLifecycleState.resumed;
    _globalState.setAppInForeground(isAppInForeground);
    debugPrint("[APP LIFECYCLE] - App is in foreground: $isAppInForeground");
  }

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