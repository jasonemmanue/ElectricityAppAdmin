import 'package:flutter/material.dart';

import 'appointments_screen.dart';
import 'conversations_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

/// The persistent 5-tab shell wrapping the admin app.
/// Bottom nav is always visible; each tab has its own Navigator stack for
/// smooth push/pop within a section.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  final _sections = const <_Section>[
    _Section(icon: Icons.dashboard_rounded, label: 'Tableau', child: DashboardScreen()),
    _Section(icon: Icons.chat_bubble_rounded, label: 'Messages', child: ConversationsScreen()),
    _Section(icon: Icons.event_note_rounded, label: 'RDV', child: AppointmentsScreen()),
    _Section(icon: Icons.people_alt_rounded, label: 'Clients', child: UsersScreen()),
    _Section(icon: Icons.settings_rounded, label: 'Réglages', child: SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _sections.map((s) => _KeepAlive(child: s.child)).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final s in _sections)
            NavigationDestination(icon: Icon(s.icon), label: s.label),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String label;
  final Widget child;
  const _Section({required this.icon, required this.label, required this.child});
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
