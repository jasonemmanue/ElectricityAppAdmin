// lib/screens/client_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientDetailsScreen extends StatelessWidget {
  final String userId;
  final String userEmail;

  const ClientDetailsScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(userEmail),
          backgroundColor: Colors.blue.shade800,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: Icon(Icons.calendar_today),
                text: 'Rendez-vous',
              ),
              Tab(
                icon: Icon(Icons.chat_bubble),
                text: 'Chat',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AppointmentsList(userId: userId),
            AdminChatView(userId: userId, userEmail: userEmail),
          ],
        ),
      ),
    );
  }
}

// ===============================================
// == WIDGET POUR L'ONGLET DES RENDEZ-VOUS ==
// ===============================================
class AppointmentsList extends StatelessWidget {
  final String userId;
  const AppointmentsList({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aucun rendez-vous pour ce client.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final appointments = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appt = appointments[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(Icons.assignment, color: Colors.orange),
                title: Text(
                  appt['service'] ?? 'Service non spécifié',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Le ${appt['date']} à ${appt['time']}'),
                    Text(appt['address'] ?? 'Adresse non fournie'),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    appt['status'] ?? 'En attente',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue.shade700,
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

// ===============================================
// == WIDGET POUR L'ONGLET DU CHAT ==
// ===============================================
class AdminChatView extends StatefulWidget {
  final String userId;
  final String userEmail;
  const AdminChatView({Key? key, required this.userId, required this.userEmail}) : super(key: key);

  @override
  _AdminChatViewState createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  final TextEditingController _textController = TextEditingController();

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();

    // On sauvegarde le message de l'admin
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.userId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': 'admin', // Identifiant spécial pour l'administrateur
      'timestamp': Timestamp.now(),
    });

    // On met à jour la date du dernier message pour le tri
    FirebaseFirestore.instance.collection('chats').doc(widget.userId).set({
      'lastMessageAt': Timestamp.now(),
      'userEmail': widget.userEmail,
    }, SetOptions(merge: true)); // merge: true pour ne pas écraser les autres champs
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.userId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!.docs;

              if(messages.isEmpty) return const Center(child: Text("Aucun message."));

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  var message = messages[index].data() as Map<String, dynamic>;
                  return _buildMessageBubble(message);
                },
              );
            },
          ),
        ),
        _buildMessageComposer(),
      ],
    );
  }

  // Ce widget est une copie de celui du client, mais adapté pour l'admin
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == 'admin'; // C'est "moi" si c'est l'admin qui envoie
    final senderName = isMe ? 'Vous (Admin)' : widget.userEmail;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? Colors.green.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message['text'] ?? '',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration.collapsed(
                hintText: 'Répondre au client...',
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(_textController.text),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}