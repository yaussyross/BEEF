import 'dart:async';
import 'dart:convert';

import 'package:beef/api/chat_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('REST read posts only to the authenticated thread endpoint', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: MemoryTokens(),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/threads/thread-a/read');
        expect(request.headers['Authorization'], 'Bearer test-access');
        expect(jsonDecode(request.body), isEmpty);
        return http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(client.close);
    await ChatApi(client).markRead('thread-a');
  });

  test(
    'socket-unavailable history marks read over HTTP and refreshes inbox',
    () async {
      final api = FakeChatApi();
      final chat = ChatController(
        api: api,
        userId: 'me',
        socket: FakeChatSocket(),
      );
      addTearDown(chat.dispose);
      await chat.openThread(testThread);
      await settle();
      expect(api.readThreads, ['thread-a']);
      expect(api.inboxCalls, 1);
    },
  );

  test('failed hydration and background hydration never mark read', () async {
    final api = FakeChatApi();
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
    );
    addTearDown(chat.dispose);
    api.onHistory = (_, __) async => throw StateError('offline');
    await chat.openThread(testThread);
    expect(api.readThreads, isEmpty);
    api.onHistory = null;
    chat.setForeground(false);
    await chat.refreshHistory();
    expect(api.readThreads, isEmpty);
  });

  test(
    'read requests coalesce and transient failures retry on next hydration',
    () async {
      final api = FakeChatApi();
      final chat = ChatController(
        api: api,
        userId: 'me',
        socket: FakeChatSocket(),
      );
      addTearDown(chat.dispose);
      final pending = Completer<void>();
      api.onRead = (_) => pending.future;
      await chat.openThread(testThread);
      await chat.refreshHistory();
      expect(api.readThreads, ['thread-a']);
      pending.completeError(StateError('offline'));
      await settle();
      api.onRead = null;
      await chat.refreshHistory();
      await settle();
      expect(api.readThreads, ['thread-a', 'thread-a']);
      expect(chat.historyError, isNull);
    },
  );

  test(
    'blocked read invalidates the thread without restoring cached history',
    () async {
      final api = FakeChatApi();
      api.onRead = (_) async => throw const ApiException(
        statusCode: 403,
        code: 'blocked',
        message: 'Unavailable',
      );
      final chat = ChatController(
        api: api,
        userId: 'me',
        socket: FakeChatSocket(),
      );
      addTearDown(chat.dispose);
      await chat.openThread(testThread);
      await settle();
      expect(chat.unavailable, isTrue);
      expect(chat.messages, isEmpty);
    },
  );

  test('late read failure cannot invalidate a newer conversation', () async {
    final api = FakeChatApi();
    final pending = Completer<void>();
    api.onRead = (id) => id == testThread.id ? pending.future : Future.value();
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
    );
    addTearDown(chat.dispose);
    await chat.openThread(testThread);
    await chat.openThread(secondThread);
    pending.completeError(
      const ApiException(
        statusCode: 403,
        code: 'blocked',
        message: 'Unavailable',
      ),
    );
    await settle();
    expect(chat.activeThread, secondThread);
    expect(chat.unavailable, isFalse);
  });

  test('socket write failure uses REST without failing hydration', () async {
    final api = FakeChatApi();
    final socket = FakeChatSocket();
    final chat = ChatController(api: api, userId: 'me', socket: socket);
    addTearDown(chat.dispose);
    socket.emit({'type': 'connected'});
    socket.onSend = (_) => throw StateError('socket closed');
    await chat.openThread(testThread);
    await settle();
    expect(api.readThreads, ['thread-a']);
    expect(chat.historyError, isNull);
  });
  test('expired fallback session calls the auth handler', () async {
    final api = FakeChatApi();
    api.onRead = (_) async => throw const ApiException(
      statusCode: 401,
      code: 'expired',
      message: 'Expired',
    );
    var expired = 0;
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
      onSessionExpired: () => expired++,
    );
    addTearDown(chat.dispose);
    await chat.openThread(testThread);
    await settle();
    expect(expired, 1);
  });

  test('late completion after disposal does not refresh inbox', () async {
    final api = FakeChatApi();
    final pending = Completer<void>();
    api.onRead = (_) => pending.future;
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
    );
    await chat.openThread(testThread);
    chat.dispose();
    pending.complete();
    await settle();
    expect(api.inboxCalls, 0);
  });

  test('connected socket keeps the existing read protocol', () async {
    final api = FakeChatApi();
    final socket = FakeChatSocket();
    final chat = ChatController(api: api, userId: 'me', socket: socket);
    addTearDown(chat.dispose);
    socket.emit({'type': 'connected'});
    await chat.openThread(testThread);
    expect(socket.frames, contains({'type': 'read', 'thread_id': 'thread-a'}));
    expect(api.readThreads, isEmpty);
  });
}
