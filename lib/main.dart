import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'screens/admin_login_screen.dart';
import 'screens/animated_loading_screen.dart';
import 'services/alert_policy.dart';
import 'services/fcm_service.dart';
import 'services/global_state.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('fr_FR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notif = NotificationService();
  await notif.init();
  await notif.requestPermissions();
  await notif.requestAlarmPermissions();

  await FcmService.instance.init();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isAdmin', true);

  // Load the alert policy (urgent-alerts switch + quiet hours) before the UI
  // so Settings shows the real values on first frame.
  await AlertPolicy.instance.hydrate();

  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> with WidgetsBindingObserver {
  final GlobalState _globalState = GlobalState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _globalState.setAppInForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOS Electricity Admin',
      theme: AppTheme.lightTheme,
      home: const AnimatedLoadingScreen(nextScreen: AdminLoginScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
