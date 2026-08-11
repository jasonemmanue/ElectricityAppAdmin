import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/alert_policy.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import 'admin_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _policy = AlertPolicy.instance;

  @override
  void initState() {
    super.initState();
    if (!_policy.isLoaded) _policy.hydrate();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _policy.quietStart : _policy.quietEnd,
      helpText: isStart ? 'Début des heures calmes' : 'Fin des heures calmes',
    );
    if (picked == null) return;
    if (isStart) {
      await _policy.setQuietStart(picked);
    } else {
      await _policy.setQuietEnd(picked);
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _policy,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
                  value: _policy.urgentEnabled,
                  onChanged: _policy.isLoaded ? _policy.setUrgentEnabled : null,
                  title: const Text('Alertes urgentes (plein écran)'),
                  subtitle: const Text('Sonne même en mode ne pas déranger'),
                  secondary: const Icon(Icons.notifications_active),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _policy.quietEnabled,
                  onChanged: _policy.isLoaded && _policy.urgentEnabled
                      ? _policy.setQuietEnabled
                      : null,
                  title: const Text('Heures calmes'),
                  subtitle: Text(
                    _policy.quietEnabled
                        ? 'Aucune sonnerie de ${_fmt(_policy.quietStart)} à ${_fmt(_policy.quietEnd)} — les alertes arrivent en silence'
                        : 'Les alertes urgentes sonnent à toute heure',
                  ),
                  secondary: const Icon(Icons.bedtime_outlined),
                ),
                if (_policy.quietEnabled && _policy.urgentEnabled) ...[
                  const Divider(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.nightlight_outlined),
                          title: const Text('Début'),
                          subtitle: Text(_fmt(_policy.quietStart)),
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.wb_sunny_outlined),
                          title: const Text('Fin'),
                          subtitle: Text(_fmt(_policy.quietEnd)),
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
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
