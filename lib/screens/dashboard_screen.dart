import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apptsStream = FirebaseFirestore.instance.collection('appointments').snapshots();
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Actualisé')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(),
              StreamBuilder<QuerySnapshot>(
                stream: apptsStream,
                builder: (context, apptSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: usersStream,
                    builder: (context, userSnap) {
                      final appts = apptSnap.data?.docs ?? [];
                      final users = userSnap.data?.docs ?? [];
                      return _StatsGrid(appts: appts, usersCount: users.length);
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Activité (7 derniers jours)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: apptsStream,
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  return _WeeklyChart(docs: docs);
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Derniers rendez-vous',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _RecentAppointments(),
              const SizedBox(height: 16),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : (now.hour < 18 ? 'Bon après-midi' : 'Bonsoir');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting Julio 👋',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  DateFormat("EEEE d MMMM y", 'fr_FR').format(now),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Voici un aperçu de votre activité aujourd\'hui.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.electric_bolt_rounded, color: AppTheme.accent, size: 32),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.appts, required this.usersCount});
  final List<QueryDocumentSnapshot> appts;
  final int usersCount;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    int pending = 0, todayCount = 0, done = 0;

    for (final d in appts) {
      final m = d.data() as Map<String, dynamic>;
      final status = (m['status'] ?? 'En attente') as String;
      if (status == 'En attente') pending++;
      if (status == 'Terminé') done++;
      final date = m['date'] as String?;
      if (date == todayStr) todayCount++;
    }

    final cards = <_StatCard>[
      _StatCard(
        icon: Icons.people_alt_rounded,
        color: AppTheme.info,
        label: 'Clients',
        value: '$usersCount',
        onTap: () => _navToTab(context, 3),
      ),
      _StatCard(
        icon: Icons.pending_actions_rounded,
        color: AppTheme.warning,
        label: 'RDV en attente',
        value: '$pending',
        onTap: () => _navToTab(context, 2),
      ),
      _StatCard(
        icon: Icons.event_available_rounded,
        color: AppTheme.success,
        label: "Aujourd'hui",
        value: '$todayCount',
        onTap: () => _navToTab(context, 2),
      ),
      _StatCard(
        icon: Icons.check_circle_rounded,
        color: AppTheme.primary,
        label: 'Terminés',
        value: '$done',
        onTap: () => _navToTab(context, 2),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        // Fixed tile height (mainAxisExtent) instead of childAspectRatio —
        // childAspectRatio varies with screen width and could still overflow.
        // 118dp comfortably fits the icon + value + label; the card content
        // is also wrapped in a FittedBox so it can never overflow whatever
        // the device or textScale.
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 118,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  void _navToTab(BuildContext context, int idx) {
    // Replace the current shell with a shell opened on the target tab.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeShell(initialIndex: idx)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          // FittedBox scales the whole column down if it would ever exceed the
          // tile — so no more "BOTTOM OVERFLOWED" whatever the device / font.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(value,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.docs});
  final List<QueryDocumentSnapshot> docs;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final buckets = List<int>.filled(7, 0);
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      DateTime? dt;
      final ts = m['createdAt'];
      if (ts is Timestamp) dt = ts.toDate();
      if (dt == null) continue;
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;
      if (diff >= 0 && diff < 7) buckets[6 - diff]++;
    }
    final maxY = (buckets.reduce((a, b) => a > b ? a : b)).toDouble();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxY == 0 ? 4 : maxY + 2),
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) {
                      final day = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          DateFormat('E', 'fr_FR').format(day).substring(0, 3),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(7, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: buckets[i].toDouble(),
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 18,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    )
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentAppointments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Aucun rendez-vous pour le moment.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return Column(
          children: docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            final status = (m['status'] ?? 'En attente') as String;
            final service = (m['service'] ?? '—') as String;
            final address = (m['address'] ?? '—') as String;
            final ts = m['createdAt'];
            final when = ts is Timestamp
                ? DateFormat('d MMM • HH:mm', 'fr_FR').format(ts.toDate())
                : '';
            final color = AppTheme.statusColor(status);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.event_rounded, color: color),
                ),
                title: Text(service, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$address\n$when'),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Indices must match HomeShell._sections order (4 tabs, no Messages).
              _footerBtn(context, Icons.dashboard_rounded, 'Tableau', 0),
              _footerBtn(context, Icons.event_note_rounded, 'RDV', 1),
              _footerBtn(context, Icons.people_alt_rounded, 'Clients', 2),
              _footerBtn(context, Icons.settings_rounded, 'Réglages', 3),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} SOS Electricity Admin • v1.0',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _footerBtn(BuildContext context, IconData icon, String label, int idx) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell(initialIndex: idx))),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
