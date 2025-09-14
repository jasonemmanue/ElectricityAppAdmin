// PROJET ADMIN - Fichier : lib/screens/client_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/notification_service.dart';
import '../widgets/message_bubble.dart';
import 'map_screen.dart';

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

class _ClientDetailsScreenState extends State<ClientDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _resetCountersForCurrentTab(0);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _resetCountersForCurrentTab(_tabController.index);
  }

  void _resetCountersForCurrentTab(int index) {
    final docRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.userId);
    if (index == 0) {
      docRef.set({'unreadAppointmentCountAdmin': 0}, SetOptions(merge: true));
    } else if (index == 1) {
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
            Tab(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.data() != null
                      ? (snapshot.data!.data()!
                  as Map<String, dynamic>)['unreadAppointmentCountAdmin'] ??
                      0
                      : 0;
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
            Tab(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.data() != null
                      ? (snapshot.data!.data()!
                  as Map<String, dynamic>)['unreadChatCountAdmin'] ??
                      0
                      : 0;
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
          AppointmentsList(userId: widget.userId, userEmail: widget.userEmail),
          AdminChatView(userId: widget.userId),
        ],
      ),
    );
  }
}

// WIDGET POUR AFFICHER LA LISTE DES RENDEZ-VOUS
class AppointmentsList extends StatelessWidget {
  final String userId;
  final String userEmail;
  const AppointmentsList({Key? key, required this.userId, required this.userEmail}) : super(key: key);

  void _updateAppointmentStatus(String appointmentId, String status) {
    FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': status});
  }

  Future<void> _scheduleOrUpdateReminder(BuildContext context, DocumentSnapshot appointmentDoc) async {
    // La vérification des permissions est maintenant dans main.dart
    var appt = appointmentDoc.data() as Map<String, dynamic>;
    DateTime? createdAt = (appt['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(createdAt),
    );

    if (pickedTime == null) return;

    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (finalDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de programmer un rappel dans le passé.')),
      );
      return;
    }

    final notificationId = appointmentDoc.id.hashCode;

    await NotificationService().scheduleNotification(
      notificationId,
      'Rappel de rendez-vous',
      'Rendez-vous pour ${appt['service']} avec $userEmail.',
      finalDateTime,
    );

    await FirebaseFirestore.instance.collection('appointments').doc(appointmentDoc.id).update({
      'reminder': {
        'notificationId': notificationId,
        'scheduledAt': Timestamp.fromDate(finalDateTime),
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rappel programmé pour ${DateFormat('dd/MM/yyyy HH:mm').format(finalDateTime)}')),
    );
  }

  Future<void> _cancelReminder(BuildContext context, DocumentSnapshot appointmentDoc) async {
    var appt = appointmentDoc.data() as Map<String, dynamic>;
    final reminderData = appt['reminder'] as Map<String, dynamic>?;

    if (reminderData != null && reminderData['notificationId'] != null) {
      final notificationId = reminderData['notificationId'];
      await NotificationService().cancelNotification(notificationId);

      await FirebaseFirestore.instance.collection('appointments').doc(appointmentDoc.id).update({
        'reminder': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappel annulé.')),
      );
    }
  }

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
          return const Center(
              child: Text("Erreur de chargement des rendez-vous."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('Aucun rendez-vous pour ce client.'));
        }
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appointmentDoc = appointments[index];
            var appt = appointmentDoc.data() as Map<String, dynamic>;
            DateTime? createdAt = (appt['createdAt'] as Timestamp?)?.toDate();
            String formattedDate = createdAt != null
                ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt)
                : 'Date inconnue';
            GeoPoint? location = appt['location'];
            String status = appt['status'] ?? 'En attente';
            final reminderData = appt['reminder'] as Map<String, dynamic>?;
            final bool isReminderSet = reminderData != null && reminderData['scheduledAt'] != null;

            return Card(
              elevation: 2,
              margin:
              const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(appt['service'] ?? 'Service non spécifié',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Pris le: $formattedDate\nAdresse: ${appt['address'] ?? 'Non fournie'}'),
                    isThreeLine: true,
                    trailing: location != null
                        ? IconButton(
                      icon: const Icon(Icons.map,
                          color: Colors.blueAccent),
                      tooltip: 'Voir sur la carte',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MapScreen(location: location),
                          ),
                        );
                      },
                    )
                        : const Icon(Icons.location_off,
                        size: 20, color: Colors.grey),
                  ),

                  if (isReminderSet)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Rappel programmé pour le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format((reminderData!['scheduledAt'] as Timestamp).toDate())}',
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
                      ),
                    ),

                  ButtonBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (status == 'En attente') ...[
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          label: const Text('Accepter'),
                          onPressed: () => _updateAppointmentStatus(appointmentDoc.id, 'Accepté'),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Refuser'),
                          onPressed: () => _updateAppointmentStatus(appointmentDoc.id, 'Refusé'),
                        ),
                      ],
                      TextButton.icon(
                        icon: Icon(isReminderSet ? Icons.edit_notifications : Icons.add_alarm, color: Colors.orange),
                        label: Text(isReminderSet ? 'Modifier' : 'Rappel'),
                        onPressed: () => _scheduleOrUpdateReminder(context, appointmentDoc),
                      ),
                      if (isReminderSet)
                        TextButton.icon(
                          icon: const Icon(Icons.notifications_off, color: Colors.grey),
                          label: const Text('Annuler'),
                          onPressed: () => _cancelReminder(context, appointmentDoc),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Le reste du fichier (AdminChatView) ne change pas.
class AdminChatView extends StatefulWidget {
  final String userId;
  const AdminChatView({Key? key, required this.userId}) : super(key: key);

  @override
  _AdminChatViewState createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  DocumentSnapshot? _replyingTo;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    Map<String, dynamic> messageData = {
      'text': _messageController.text,
      'senderId': 'admin',
      'timestamp': Timestamp.now(),
      if (_replyingTo != null)
        'replyingTo': {
          'messageId': _replyingTo!.id,
          'text': _replyingTo!['text']
        }
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.userId)
        .collection('messages')
        .add(messageData);
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.userId)
        .set({'lastMessageAt': Timestamp.now()}, SetOptions(merge: true));

    _messageController.clear();
    setState(() => _replyingTo = null);
  }

  void _scrollToMessage(String messageId, List<DocumentSnapshot> messages) {
    final index = messages.indexWhere((doc) => doc.id == messageId);
    if (index != -1) {
      _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          alignment: 0.5);
    }
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
                .orderBy('timestamp')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                    child: Text('Erreur de connexion: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text("Commencez la conversation."));

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

        final plainText =
            messageData['text'] as String? ?? '';
        final messageTimestamp =
        (messageData['timestamp'] as Timestamp).toDate();
        final isMe = messageData['senderId'] == 'admin';

        final replyData = messageData['replyingTo'] as Map<String, dynamic>?;
        final repliedTextPlain = replyData != null
            ? replyData['text'] as String?
            : null;

        bool showDateSeparator = false;
        if (index == 0) {
          showDateSeparator = true;
        } else {
          final prevTimestamp =
          (messages[index - 1]['timestamp'] as Timestamp).toDate();
          if (messageTimestamp.day != prevTimestamp.day ||
              messageTimestamp.month != prevTimestamp.month ||
              messageTimestamp.year != prevTimestamp.year) {
            showDateSeparator = true;
          }
        }

        final messageBubble = Dismissible(
          key: Key(messageDoc.id),
          direction: DismissDirection.startToEnd,
          onDismissed: (_) {
            setState(() {
              _replyingTo = messageDoc;
            });
          },
          background: Container(
            color: Colors.blue.shade100,
            alignment: Alignment.centerLeft,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.reply, color: Colors.blue)),
          ),
          child: MessageBubble(
            text: plainText,
            timestamp: messageTimestamp,
            isMe: isMe,
            repliedText: repliedTextPlain,
            onQuoteTap: replyData == null
                ? null
                : () => _scrollToMessage(replyData['messageId'], messages),
          ),
        );

        if (showDateSeparator) {
          return Column(
              children: [_buildDateSeparator(messageTimestamp), messageBubble]);
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
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }

  Widget _buildMessageComposer() {
    final replyingToText =
    _replyingTo != null ? _replyingTo!['text'] as String? : null;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              blurRadius: 3,
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12))),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text("En réponse à : $replyingToText",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontStyle: FontStyle.italic))),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _replyingTo = null)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}