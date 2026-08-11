import 'package:flutter/material.dart';

import '../services/notification_router.dart';
import 'appointments_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

/// The persistent 4-tab shell wrapping the admin app.
/// The Messages tab was removed — chat is still accessible per-client from
/// Clients → open a client → Chat tab.
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

  @override
  void initState() {
    super.initState();
    // A tapped notification asks for a tab through this notifier — it has no
    // BuildContext of its own, and the tap often lands before this shell even
    // exists (app opened from a notification while it was killed).
    NotificationRouter.requestedTab.addListener(_onTabRequested);
    // Signals that navigation is possible now, replaying any tap that arrived
    // during startup or while the login screen was up.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => NotificationRouter.onShellReady());
  }

  @override
  void dispose() {
    NotificationRouter.requestedTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final requested = NotificationRouter.requestedTab.value;
    if (!mounted || requested == _index) return;
    setState(() => _index = requested);
  }

  final _sections = const <_Section>[
    _Section(icon: Icons.dashboard_rounded, label: 'Tableau', child: DashboardScreen()),
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
        onDestinationSelected: (i) {
          // Kept in sync so a later notification asking for the tab the admin
          // already picked still registers as a change.
          NotificationRouter.requestedTab.value = i;
          setState(() => _index = i);
        },
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
