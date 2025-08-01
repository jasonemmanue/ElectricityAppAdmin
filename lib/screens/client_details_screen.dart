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
      length: 2, // Nous avons 2 onglets : Rendez-vous et Chat
      child: Scaffold(
        appBar: AppBar(
          title: Text(userEmail, style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.blue.shade800,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.calendar_today), text: 'Rendez-vous'),
              Tab(icon: Icon(Icons.chat_bubble), text: 'Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Onglet 1: Liste des rendez-vous
            AppointmentsList(userId: userId),
            // Onglet 2: Interface de chat
            AdminChatView(userId: userId, userEmail: userEmail),
          ],
        ),
      ),
    );
  }
}

// ===============================================
// == WIDGET POUR L'ONGLET DES RENDEZ-VOUS (MIS À JOUR) ==
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
        if (snapshot.hasError) {
          return const Center(child: Text("Erreur de chargement des rendez-vous."));
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
          padding: const EdgeInsets.all(10.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appt = appointments[index].data() as Map<String, dynamic>;

            // --- Logique pour afficher les informations de paiement ---
            final totalAmount = appt['montant_total']?.toString() ?? 'N/A';
            final paidAmount = appt['montant_envoye']?.toString() ?? 'N/A';
            final paymentMethod = appt['methode_paiement'] ?? 'N/A';

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- EN-TÊTE DE LA CARTE ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            appt['service'] ?? 'Service',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        Chip(
                          label: Text(
                            appt['status'] ?? 'En attente',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // --- DÉTAILS DU RENDEZ-VOUS ---
                    InfoRow(icon: Icons.calendar_today, text: '${appt['date']} à ${appt['time']}'),
                    const SizedBox(height: 8),
                    InfoRow(icon: Icons.location_on, text: appt['address'] ?? 'Adresse non fournie'),
                    const SizedBox(height: 12),

                    // --- SECTION PAIEMENT ---
                    const Text("Détails du paiement", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    InfoRow(icon: Icons.receipt_long, text: 'Total estimé: $totalAmount FCFA'),
                    const SizedBox(height: 8),
                    InfoRow(icon: Icons.payment, text: 'Avance payée: $paidAmount FCFA ($paymentMethod)'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Petit widget pour uniformiser l'affichage des lignes d'information
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoRow({Key? key, required this.icon, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}


// ===============================================
// == WIDGET POUR L'ONGLET DU CHAT (INCHANGÉ) ==
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

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.userId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': 'admin',
      'timestamp': Timestamp.now(),
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.userId).set({
      'lastMessageAt': Timestamp.now(),
      'userEmail': widget.userEmail,
    }, SetOptions(merge: true));
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

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == 'admin';
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