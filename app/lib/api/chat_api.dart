import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import 'http_client.dart';

class ChatHistory {
  const ChatHistory(this.messages, this.nextCursor);
  final List<ChatMessage> messages;
  final String? nextCursor;
}

class ChatApi {
  ChatApi(this.client);
  final ApiClient client;

  Future<List<ChatThread>> inbox() async {
    final data = await client
        .get('/api/threads')
        .timeout(const Duration(seconds: 20));
    return (data['threads'] as List)
        .cast<Map<String, dynamic>>()
        .map(ChatThread.fromJson)
        .toList();
  }

  Future<ChatThread> startThread(String userId) async {
    final data = await client
        .post('/api/threads', body: {'other_user_id': userId})
        .timeout(const Duration(seconds: 20));
    return ChatThread.fromJson(data['thread'] as Map<String, dynamic>);
  }

  Future<ChatHistory> history(String threadId, {String? cursor}) async {
    final query = Uri(
      queryParameters: {'limit': '50', if (cursor != null) 'cursor': cursor},
    ).query;
    final data = await client
        .get('/api/threads/${Uri.encodeComponent(threadId)}/messages?$query')
        .timeout(const Duration(seconds: 20));
    return ChatHistory(
      (data['messages'] as List)
          .cast<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
      data['next_cursor'] as String?,
    );
  }

  Future<ChatMessage> send(
    String threadId,
    String clientId,
    String body,
  ) async {
    final data = await client
        .post(
          '/api/threads/${Uri.encodeComponent(threadId)}/messages',
          body: {'client_message_id': clientId, 'body': body},
        )
        .timeout(const Duration(seconds: 20));
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }
}
