enum MessageDelivery { sent, sending, failed }

/// Chat payloads intentionally have no location or birthdate fields.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.moderationStatus,
    required this.createdAt,
    this.delivery = MessageDelivery.sent,
    this.error,
  });

  final String id, threadId, senderId, clientMessageId, body, moderationStatus;
  final DateTime createdAt;
  final MessageDelivery delivery;
  final String? error;

  // Fail closed for pending, rejected, blurred, and unknown moderation states.
  bool get isVisible => moderationStatus == 'approved';
  String get displayBody =>
      isVisible ? body : 'Message hidden for safety review.';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    threadId: json['thread_id'] as String? ?? '',
    senderId: json['sender_id'] as String,
    clientMessageId: json['client_message_id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    moderationStatus: json['moderation_status'] as String? ?? 'pending',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  ChatMessage withDelivery(MessageDelivery value, {String? error}) =>
      ChatMessage(
        id: id,
        threadId: threadId,
        senderId: senderId,
        clientMessageId: clientMessageId,
        body: body,
        moderationStatus: moderationStatus,
        createdAt: createdAt,
        delivery: value,
        error: error,
      );
}
