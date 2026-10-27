import 'dart:async';
import 'dart:convert';

import 'package:beef/api/chat_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/api/token_store.dart';
import 'package:beef/chat/chat_socket.dart';
import 'package:beef/models/chat_message.dart';
import 'package:beef/models/chat_thread.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokens implements TokenStore {
  String? access = 'test-access';
  String? refresh = 'test-refresh';
  @override
  Future<String?> readAccessToken() async => access;
  @override
  Future<String?> readRefreshToken() async => refresh;
  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

const testThread = ChatThread(
  id: 'thread-a',
  otherUserId: 'other',
  displayName: 'Test conversation',
);
const secondThread = ChatThread(
  id: 'thread-b',
  otherUserId: 'another',
  displayName: 'Another conversation',
);

Map<String, dynamic> messageJson({
  String id = 'message-1',
  String thread = 'thread-a',
  String sender = 'other',
  String client = 'client-1',
  String status = 'approved',
  String body = 'Hello',
}) => {
  'id': id,
  'thread_id': thread,
  'sender_id': sender,
  'client_message_id': client,
  'body': body,
  'moderation_status': status,
  'created_at': '2026-10-06T20:00:00Z',
};

class FakeChatApi extends ChatApi {
  FakeChatApi()
    : super(
        ApiClient(
          baseUrl: 'https://example.test',
          tokenStore: MemoryTokens(),
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode({}), 200),
          ),
        ),
      );
  List<ChatThread> threads = [testThread];
  Future<ChatHistory> Function(String, String?)? onHistory;
  Future<ChatMessage> Function(String, String, String)? onSend;
  final sentIds = <String>[];
  int inboxCalls = 0;
  @override
  Future<List<ChatThread>> inbox() async {
    inboxCalls++;
    return List.of(threads);
  }

  @override
  Future<ChatThread> startThread(String userId) async => testThread;
  @override
  Future<ChatHistory> history(String threadId, {String? cursor}) async =>
      onHistory == null
      ? const ChatHistory([], null)
      : onHistory!(threadId, cursor);
  @override
  Future<ChatMessage> send(
    String threadId,
    String clientId,
    String body,
  ) async {
    sentIds.add(clientId);
    if (onSend != null) {
      return onSend!(threadId, clientId, body);
    }
    return ChatMessage.fromJson(
      messageJson(thread: threadId, sender: 'me', client: clientId, body: body),
    );
  }
}

class FakeChatSocket implements ChatSocket {
  final controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final frames = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic>)? onSend;
  int disconnects = 0;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  void emit(Map<String, dynamic> event) => controller.add(event);
  @override
  Future<void> connect(String baseUrl, String token) async =>
      emit({'type': 'connected'});
  @override
  Future<void> disconnect() async {
    disconnects++;
  }

  @override
  void send(Map<String, dynamic> frame) {
    frames.add(frame);
    onSend?.call(frame);
  }

  @override
  void dispose() {
    unawaited(controller.close());
  }
}
