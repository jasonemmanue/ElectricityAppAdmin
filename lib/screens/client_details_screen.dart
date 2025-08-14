// PROJET ADMIN - Fichier : lib/screens/client_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/encryption_service.dart';
import '../widgets/message_bubble.dart';

// WIDGET PRINCIPAL QUI GÈRE LES ONGLETS
class ClientDetailsScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const ClientDetailsScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  _ClientDetailsScreenState createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _tabController = TabController(length: 2, vsync: this);
    // Gère la réinitialisation des compteurs de notification
    _tabController.addListener(_handleTabSelection);
    // Réinitialise le compteur du premier onglet dès l'ouverture
    _resetCountersForCurrentTab(0);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _resetCountersForCurrentTab(_tabController.index);
  }

  void _resetCountersForCurrentTab(int index) {
    final docRef = FirebaseFirestore.instance.collection('chats').doc(widget.userId);
    // Onglet Rendez-vous
    if (index == 0) {
      docRef.set({'unreadAppointmentCountAdmin': 0}, SetOptions(merge: true));
    }
    // Onglet Chat
    else if (index == 1) {
      docRef.set({'unreadChatCountAdmin': 0}, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userEmail, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.blue.shade800,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            // Onglet Rendez-vous avec son compteur de notifications
            Tab(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(widget.userId).snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.data() != null ? (snapshot.data!.data()! as Map<String, dynamic>)['unreadAppointmentCountAdmin'] ?? 0 : 0;
                  return Badge(
                    label: Text('$count'),
                    isLabelVisible: count > 0,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today),
                        SizedBox(width: 8),
                        Text('RDV'),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Onglet Chat avec son compteur de notifications
            Tab(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(widget.userId).snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.data() != null ? (snapshot.data!.data()! as Map<String, dynamic>)['unreadChatCountAdmin'] ?? 0 : 0;
                  return Badge(
                    label: Text('$count'),
                    isLabelVisible: count > 0,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble),
                        SizedBox(width: 8),
                        Text('Chat'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Contenu du premier onglet
          AppointmentsList(userId: widget.userId),
          // Contenu du deuxième onglet
          AdminChatView(userId: widget.userId),
        ],
      ),
    );
  }
}

// WIDGET POUR AFFICHER LA LISTE DES RENDEZ-VOUS
class AppointmentsList extends StatelessWidget {
  final String userId;
  const AppointmentsList({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Erreur de chargement des rendez-vous."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun rendez-vous pour ce client.'));
        }
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appt = appointments[index].data() as Map<String, dynamic>;
            DateTime? createdAt = (appt['createdAt'] as Timestamp?)?.toDate();
            String formattedDate = createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt) : 'Date inconnue';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
              child: ListTile(
                title: Text(appt['service'] ?? 'Service non spécifié', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Pris le: $formattedDate\nAdresse: ${appt['address'] ?? 'Non fournie'}'),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}

// WIDGET POUR GÉRER TOUTE LA VUE DU CHAT
class AdminChatView extends StatefulWidget {
  final String userId;
  const AdminChatView({Key? key, required this.userId}) : super(key: key);

  @override
  _AdminChatViewState createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  final TextEditingController _messageController = TextEditingController();
  final EncryptionService _encryptionService = EncryptionService();
  final ItemScrollController _itemScrollController = ItemScrollController();
  DocumentSnapshot? _replyingTo;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // On s'assure de chiffrer le message de l'admin avant de l'envoyer.
    final encryptedText = _encryptionService.encryptText(_messageController.text);

    Map<String, dynamic> messageData = {
      'text': encryptedText,
      'senderId': 'admin',
      'timestamp': Timestamp.now(),
      if (_replyingTo != null)
        'replyingTo': {'messageId': _replyingTo!.id, 'text': _replyingTo!['text']}
    };

    await FirebaseFirestore.instance.collection('chats').doc(widget.userId).collection('messages').add(messageData);
    await FirebaseFirestore.instance.collection('chats').doc(widget.userId).set({'lastMessageAt': Timestamp.now()}, SetOptions(merge: true));

    _messageController.clear();
    setState(() => _replyingTo = null);
  }

  void _scrollToMessage(String messageId, List<DocumentSnapshot> messages) {
    final index = messages.indexWhere((doc) => doc.id == messageId);
    if (index != -1) {
      _itemScrollController.scrollTo(index: index, duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic, alignment: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.userId).collection('messages').orderBy('timestamp').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erreur de connexion: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Commencez la conversation."));

              final messages = snapshot.data!.docs;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_itemScrollController.isAttached) {
                  _itemScrollController.jumpTo(index: messages.length - 1);
                }
              });
              return _buildMessagesList(messages);
            },
          ),
        ),
        _buildMessageComposer(),
      ],
    );
  }

  Widget _buildMessagesList(List<DocumentSnapshot> messages) {
    return ScrollablePositionedList.builder(
      itemCount: messages.length,
      itemScrollController: _itemScrollController,
      itemBuilder: (context, index) {
        final messageDoc = messages[index];
        final messageData = messageDoc.data() as Map<String, dynamic>;

        final decryptedText = _encryptionService.decryptText(messageData['text']);
        final messageTimestamp = (messageData['timestamp'] as Timestamp).toDate();
        final isMe = messageData['senderId'] == 'admin';

        final replyData = messageData['replyingTo'] as Map<String, dynamic>?;
        final decryptedRepliedText = replyData != null ? _encryptionService.decryptText(replyData['text']) : null;

        bool showDateSeparator = false;
        if (index == 0) {
          showDateSeparator = true;
        } else {
          final prevTimestamp = (messages[index-1]['timestamp'] as Timestamp).toDate();
          if (messageTimestamp.day != prevTimestamp.day || messageTimestamp.month != prevTimestamp.month || messageTimestamp.year != prevTimestamp.year) {
            showDateSeparator = true;
          }
        }

        final messageBubble = Dismissible(
          key: Key(messageDoc.id),
          direction: DismissDirection.startToEnd,
          onDismissed: (_) { setState(() { _replyingTo = messageDoc; }); },
          background: Container(
            color: Colors.blue.shade100,
            alignment: Alignment.centerLeft,
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Icon(Icons.reply, color: Colors.blue)),
          ),
          child: MessageBubble(
            text: decryptedText,
            timestamp: messageTimestamp,
            isMe: isMe,
            repliedText: decryptedRepliedText,
            onQuoteTap: replyData == null ? null : () => _scrollToMessage(replyData['messageId'], messages),
          ),
        );

        if (showDateSeparator) {
          return Column(children: [_buildDateSeparator(messageTimestamp), messageBubble]);
        }
        return messageBubble;
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    String text;
    if (dateToCompare == today) {
      text = "Aujourd'hui";
    } else if (dateToCompare == yesterday) {
      text = "Hier";
    } else {
      text = DateFormat.yMMMMEEEEd('fr_FR').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }

  Widget _buildMessageComposer() {
    final replyingToText = _replyingTo != null ? _encryptionService.decryptText(_replyingTo!['text']) : null;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(blurRadius: 3, color: Colors.grey.withOpacity(0.2), spreadRadius: 1)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("En réponse à : $replyingToText", overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyingTo = null)),
                ],
              ),
            ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Répondre au client...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}