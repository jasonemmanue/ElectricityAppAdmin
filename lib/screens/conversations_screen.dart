import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'client_details_screen.dart';

/// Rebranded list of conversations (replaces the old admin_dashboard_screen).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un client…',
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
        stream: FirebaseFirestore.instance
            .collection('chats')
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          var docs = snap.data?.docs ?? [];
          if (_query.isNotEmpty) {
            docs = docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              final email = (m['userEmail'] ?? '') as String;
              return email.toLowerCase().contains(_query);
            }).toList();
          }
          if (docs.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final chat = docs[i].data() as Map<String, dynamic>;
              final userId = (chat['userId'] ?? docs[i].id) as String;
              final email = (chat['userEmail'] ?? 'Email inconnu') as String;
              final unreadChats = (chat['unreadChatCountAdmin'] ?? 0) as num;
              final unreadAppt = (chat['unreadAppointmentCountAdmin'] ?? 0) as num;
              final total = (unreadChats + unreadAppt).toInt();
              final lastMsg = chat['lastMessageAt'];
              final when = lastMsg is Timestamp
                  ? _formatWhen(lastMsg.toDate())
                  : '';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    child: Text(
                      _initialsOf(email),
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(when, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: total > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$total',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        )
                      : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientDetailsScreen(userId: userId, userEmail: email),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _initialsOf(String email) {
    final trimmed = email.split('@').first;
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    if (that == today) return "Aujourd'hui à ${DateFormat('HH:mm').format(dt)}";
    if (today.difference(that).inDays == 1) return "Hier à ${DateFormat('HH:mm').format(dt)}";
    return DateFormat('d MMM • HH:mm', 'fr_FR').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text('Aucune conversation client',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Dès qu\'un client vous écrit, il apparaîtra ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
