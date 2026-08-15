import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'client_details_screen.dart';

/// What the `chats/{uid}` document contributes to a client's row: who is
/// waiting on an answer, and since when.
class _ChatMeta {
  const _ChatMeta({
    this.unreadChat = 0,
    this.unreadAppointments = 0,
    this.lastMessageAt,
  });

  final int unreadChat;
  final int unreadAppointments;
  final DateTime? lastMessageAt;

  int get unreadTotal => unreadChat + unreadAppointments;
  bool get hasUnread => unreadTotal > 0;

  static _ChatMeta from(Map<String, dynamic> m) => _ChatMeta(
        unreadChat: (m['unreadChatCountAdmin'] as num?)?.toInt() ?? 0,
        unreadAppointments:
            (m['unreadAppointmentCountAdmin'] as num?)?.toInt() ?? 0,
        lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate(),
      );
}

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
      // The unread counters live on `chats/{uid}`, not on the user document, so
      // the list needs both collections to be able to show who is waiting.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').snapshots(),
        builder: (context, chatSnap) {
          final chats = <String, _ChatMeta>{
            for (final d in chatSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
              d.id: _ChatMeta.from(d.data() as Map<String, dynamic>),
          };
          return _buildUserList(chats);
        },
      ),
    );
  }

  Widget _buildUserList(Map<String, _ChatMeta> chats) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));

        // Copied before sorting: `docs` comes straight from the snapshot and
        // is not ours to reorder in place.
        var docs = List<QueryDocumentSnapshot>.of(snap.data?.docs ?? []);
        if (_query.isNotEmpty) {
          docs = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final email = ((m['email'] ?? '') as String).toLowerCase();
            final name = ((m['fullName'] ?? '') as String).toLowerCase();
            return email.contains(_query) || name.contains(_query);
          }).toList();
        }

        // Anyone waiting on a reply comes first — that is the whole point of
        // this screen — then the most recent conversations.
        docs.sort((a, b) {
          final ca = chats[a.id] ?? const _ChatMeta();
          final cb = chats[b.id] ?? const _ChatMeta();
          if (ca.hasUnread != cb.hasUnread) return ca.hasUnread ? -1 : 1;
          final ta = ca.lastMessageAt;
          final tb = cb.lastMessageAt;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline,
                    size: 64, color: AppTheme.textSecondary.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('Aucun client trouvé',
                    style: TextStyle(color: AppTheme.textSecondary)),
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
            final chat = chats[uid] ?? const _ChatMeta();
            final displayName = name.isNotEmpty ? name : email;

            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: chat.hasUnread
                          ? AppTheme.primary
                          : AppTheme.accent.withOpacity(0.25),
                      child: Text(
                        _initials(displayName),
                        style: TextStyle(
                          color:
                              chat.hasUnread ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (chat.hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${chat.unreadTotal}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight:
                        chat.hasUnread ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    if (phone.isNotEmpty)
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    _StatusLine(chat: chat),
                  ],
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ClientDetailsScreen(
                    userId: uid,
                    userEmail: email,
                    userName: name,
                    // Someone with an unread message wants the conversation,
                    // not the appointment list.
                    initialTab: chat.unreadChat > 0 ? 1 : 0,
                  ),
                )),
              ),
            );
          },
        );
      },
    );
  }

  String _initials(String s) {
    if (s.isEmpty) return '?';
    final trimmed = s.split('@').first.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed
        .substring(0, trimmed.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
}

/// The read / unread line under a client's name.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.chat});

  final _ChatMeta chat;

  @override
  Widget build(BuildContext context) {
    final when = chat.lastMessageAt;
    final ago = when == null ? null : _relative(when);

    if (chat.hasUnread) {
      final bits = <String>[
        if (chat.unreadChat > 0)
          '${chat.unreadChat} message${chat.unreadChat > 1 ? 's' : ''}',
        if (chat.unreadAppointments > 0)
          '${chat.unreadAppointments} RDV',
      ];
      return Row(
        children: [
          const Icon(Icons.mark_email_unread, size: 14, color: AppTheme.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${bits.join(' · ')} non lu${chat.unreadTotal > 1 ? 's' : ''}'
              '${ago != null ? ' · $ago' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (when == null) {
      return const Text('Aucun échange',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
    }

    return Row(
      children: [
        const Icon(Icons.done_all, size: 14, color: AppTheme.success),
        const SizedBox(width: 4),
        Text('Lu · $ago',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  }
}
