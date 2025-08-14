import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? repliedText;
  final VoidCallback? onQuoteTap;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.repliedText,
    this.onQuoteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String formattedTime = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isMe ? Colors.green[600] : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (repliedText != null)
                GestureDetector(
                  onTap: onQuoteTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green[400] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: isMe ? Colors.white70 : Colors.green.shade800, width: 3)),
                    ),
                    child: Text(
                      repliedText!,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isMe ? Colors.white.withOpacity(0.9) : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  formattedTime,
                  style: TextStyle(
                    color: isMe ? Colors.white.withOpacity(0.7) : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}