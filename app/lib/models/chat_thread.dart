import 'chat_message.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.otherUserId,
    required this.displayName,
    this.photoVerificationStatus = 'unverified',
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  final String id, otherUserId, displayName, photoVerificationStatus;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final dynamic last = json['last_message'];
    return ChatThread(
      id: json['id'] as String,
      otherUserId: json['other_user_id'] as String,
      displayName:
          (json['other_display_name'] as String?)?.trim().isNotEmpty == true
          ? json['other_display_name'] as String
          : 'A fellow cut',
      photoVerificationStatus:
          json['other_photo_verification_status'] as String? ?? 'unverified',
      lastMessage: last is Map<String, dynamic>
          ? ChatMessage.fromJson(last)
          : null,
      unreadCount: int.tryParse('${json['unread_count']}') ?? 0,
      lastMessageAt: DateTime.tryParse('${json['last_message_at']}'),
    );
  }
}
