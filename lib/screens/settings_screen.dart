import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import 'admin_login_screen.dart';

const String _kUrgentAlertsPrefKey = 'adminUrgentAlertsEnabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _urgentAlerts = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUrgentAlerts();
  }

  Future<void> _loadUrgentAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urgentAlerts = prefs.getBool(_kUrgentAlertsPrefKey) ?? true;
      _loaded = true;
    });
  }

  Future<void> _setUrgentAlerts(bool value) async {
    setState(() => _urgentAlerts = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUrgentAlertsPrefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: AppTheme.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Julio Kammeugne',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '—',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Administrateur',
                            style: TextStyle(color: Colors.white, fontSize: 10)),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          _sectionLabel(context, 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _urgentAlerts,
                  onChanged: _loaded ? _setUrgentAlerts : null,
                  title: const Text('Alertes urgentes (plein écran)'),
                  subtitle: const Text('Sonne même en mode ne pas déranger'),
                  secondary: const Icon(Icons.notifications_active),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Réenregistrer le token FCM'),
                  subtitle: const Text('En cas de non-réception des notifications'),
                  onTap: () async {
                    await FirebaseMessaging.instance.deleteToken();
                    await FcmService.instance.registerAfterSignIn();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token FCM régénéré')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          _sectionLabel(context, 'À propos'),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Version'),
                  trailing: Text('1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.electric_bolt_rounded),
                  title: Text('SOS Electricity Admin'),
                  subtitle: Text('Console de gestion'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: const Text('Se déconnecter', style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error, width: 1.5),
              ),
              onPressed: () async {
                await FcmService.instance.unregisterOnSignOut();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© ${DateTime.now().year} SOS Electricity',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 1.2),
        ),
      );
}
