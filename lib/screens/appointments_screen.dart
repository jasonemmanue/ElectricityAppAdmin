import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'map_screen.dart';

/// Global appointments view — cross-client, filterable by status.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static const _statuses = [
    'Tous',
    'En attente',
    'Accepté',
    'En route',
    'Sur place',
    'Terminé',
    'Refusé',
  ];

  String _filter = 'Tous';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final coll = FirebaseFirestore.instance.collection('appointments');
    if (_filter == 'Tous') {
      return coll.orderBy('createdAt', descending: true).snapshots();
    }
    return coll
        .where('status', isEqualTo: _filter)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('appointments').doc(id).update({'status': status});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : $status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendez-vous'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final s = _statuses[i];
                final selected = _filter == s;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = s),
                  backgroundColor: Colors.white.withOpacity(0.15),
                  selectedColor: AppTheme.accent,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.textPrimary : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(selected ? 0 : 0.3)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  const Text('Aucun rendez-vous', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, i) => _AppointmentCard(
              doc: docs[i],
              onUpdate: _updateStatus,
            ),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.doc, required this.onUpdate});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(String id, String status) onUpdate;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final status = (m['status'] ?? 'En attente') as String;
    final color = AppTheme.statusColor(status);
    final service = (m['service'] ?? 'Service non spécifié') as String;
    final address = (m['address'] ?? 'Non fournie') as String;
    final desc = (m['description'] ?? '') as String;
    final GeoPoint? loc = m['location'] as GeoPoint?;
    final ts = m['createdAt'];
    final when = ts is Timestamp
        ? DateFormat('EEEE d MMM y • HH:mm', 'fr_FR').format(ts.toDate())
        : '—';
    final userId = (m['userId'] ?? '') as String;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.electric_bolt_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(when,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(address, style: const TextStyle(fontSize: 13))),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (loc != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Carte'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MapScreen(location: loc)),
                      ),
                    ),
                  ),
                if (loc != null) const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<String>(
                    onSelected: (v) => onUpdate(doc.id, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Accepté', child: Text('Accepter')),
                      PopupMenuItem(value: 'Refusé', child: Text('Refuser')),
                      PopupMenuItem(value: 'En route', child: Text('En route')),
                      PopupMenuItem(value: 'Sur place', child: Text('Sur place')),
                      PopupMenuItem(value: 'Terminé', child: Text('Terminé')),
                    ],
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Changer statut',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (userId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Client: $userId',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
