import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'client_details_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher (email, nom)…',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          var docs = snap.data?.docs ?? [];
          if (_query.isNotEmpty) {
            docs = docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              final email = ((m['email'] ?? '') as String).toLowerCase();
              final name = ((m['fullName'] ?? '') as String).toLowerCase();
              return email.contains(_query) || name.contains(_query);
            }).toList();
          }
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  const Text('Aucun client trouvé', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final uid = (m['uid'] ?? docs[i].id) as String;
              final email = (m['email'] ?? '—') as String;
              final name = (m['fullName'] ?? '') as String;
              final phone = (m['phoneNumber'] ?? '') as String;
              final ts = m['createdAt'];
              final joined = ts is Timestamp
                  ? DateFormat('MMM y', 'fr_FR').format(ts.toDate())
                  : '';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.accent.withOpacity(0.25),
                    child: Text(
                      _initials(name.isNotEmpty ? name : email),
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name.isNotEmpty ? name : email,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (joined.isNotEmpty)
                        Text('Inscrit en $joined',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientDetailsScreen(userId: uid, userEmail: email),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _initials(String s) {
    if (s.isEmpty) return '?';
    final trimmed = s.split('@').first;
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}
