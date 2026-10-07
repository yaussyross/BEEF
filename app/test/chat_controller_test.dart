import 'dart:async';

import 'package:beef/api/chat_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:beef/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_helpers.dart';

void main() {
  late FakeChatApi api;
  late FakeChatSocket socket;
  late ChatController chat;
  setUp(() {
    api = FakeChatApi();
    socket = FakeChatSocket();
    chat = ChatController(
      api: api,
      userId: 'me',
      socket: socket,
      ackTimeout: const Duration(milliseconds: 5),
    );
  });
  tearDown(() => chat.dispose());

  test('REST send trims text and uses a persistent retry id', () async {
    await chat.openThread(testThread);
    var fail = true;
    api.onSend = (thread, id, text) async {
      if (fail) {
        throw StateError('offline');
      }
      return ChatMessage.fromJson(
        messageJson(thread: thread, sender: 'me', client: id, body: text),
      );
    };
    expect(await chat.send('  Hello  '), isTrue);
    expect(chat.messages.single.delivery, MessageDelivery.failed);
    expect(chat.messages.single.body, 'Hello');
    fail = false;
    await chat.retry(chat.messages.single.clientMessageId);
    expect(api.sentIds[0], api.sentIds[1]);
    expect(chat.messages.single.delivery, MessageDelivery.sent);
  });

  test('empty and oversized sends are refused before the network', () async {
    await chat.openThread(testThread);
    expect(await chat.send('   '), isFalse);
    expect(await chat.send('x' * 4001), isFalse);
    expect(api.sentIds, isEmpty);
  });

  test('double-tap cannot enqueue two in-flight messages', () async {
    final result = Completer<ChatMessage>();
    api.onSend = (_, __, ___) => result.future;
    await chat.openThread(testThread);
    final first = chat.send('Hello');
    expect(await chat.send('Hello'), isFalse);
    final pending = chat.messages.single;
    result.complete(
      ChatMessage.fromJson(
        messageJson(sender: 'me', client: pending.clientMessageId),
      ),
    );
    await first;
    expect(api.sentIds, hasLength(1));
  });

  test(
    'WS acknowledgement replaces local row without REST or duplication',
    () async {
      await chat.openThread(testThread);
      socket.emit({'type': 'connected'});
      socket.onSend = (frame) {
        if (frame['type'] == 'send') {
          socket.emit({
            'type': 'ack',
            'duplicate': false,
            'message': messageJson(
              sender: 'me',
              client: frame['client_message_id'] as String,
            ),
          });
        }
      };
      await chat.send('Hello');
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.delivery, MessageDelivery.sent);
      expect(api.sentIds, isEmpty);
    },
  );

  test('lost WS ack falls back with the exact same id', () async {
    await chat.openThread(testThread);
    socket.emit({'type': 'connected'});
    await chat.send('Hello');
    final sent = socket.frames.singleWhere((f) => f['type'] == 'send');
    expect(api.sentIds.single, sent['client_message_id']);
    socket.emit({
      'type': 'ack',
      'message': messageJson(sender: 'me', client: api.sentIds.single),
    });
    expect(chat.messages, hasLength(1));
  });

  test(
    'explicit moderation rejection is not automatically retried over REST',
    () async {
      await chat.openThread(testThread);
      socket.emit({'type': 'connected'});
      socket.onSend = (frame) {
        if (frame['type'] == 'send') {
          socket.emit({
            'type': 'error',
            'code': 'message_blocked',
            'message': 'Please rephrase.',
          });
        }
      };
      await chat.send('Rejected text');
      expect(api.sentIds, isEmpty);
      expect(chat.messages.single.delivery, MessageDelivery.failed);
      expect(chat.messages.single.error, 'Please rephrase.');
    },
  );

  test('history pagination merges and deduplicates overlapping rows', () async {
    api.onHistory = (_, cursor) async => cursor == null
        ? ChatHistory([ChatMessage.fromJson(messageJson())], 'older|id')
        : ChatHistory([
            ChatMessage.fromJson(messageJson()),
            ChatMessage.fromJson(
              messageJson(id: 'message-2', client: 'client-2'),
            ),
          ], null);
    await chat.openThread(testThread);
    expect(chat.hasMore, isTrue);
    await chat.loadOlder();
    expect(chat.messages, hasLength(2));
    expect(chat.hasMore, isFalse);
  });

  test(
    'late history from a previous route cannot overwrite the new route',
    () async {
      final delayed = Completer<ChatHistory>();
      api.onHistory = (id, _) async =>
          id == testThread.id ? delayed.future : const ChatHistory([], null);
      final first = chat.openThread(testThread);
      await chat.openThread(secondThread);
      delayed.complete(
        ChatHistory([ChatMessage.fromJson(messageJson())], null),
      );
      await first;
      expect(chat.activeThread, secondThread);
      expect(chat.messages, isEmpty);
      expect(chat.historyLoading, isFalse);
    },
  );

  test(
    'new live messages survive a history refresh already in flight',
    () async {
      await chat.openThread(testThread);
      final delayed = Completer<ChatHistory>();
      api.onHistory = (_, __) => delayed.future;
      final refresh = chat.refreshHistory();
      socket.emit({'type': 'message', 'message': messageJson(id: 'fresh')});
      delayed.complete(const ChatHistory([], null));
      await refresh;
      expect(chat.messages.single.id, 'fresh');
    },
  );

  test(
    'block closes visible history, removes inbox, and refuses further sends',
    () async {
      await chat.refreshInbox();
      await chat.openThread(testThread);
      socket.emit({'type': 'message', 'message': messageJson()});
      socket.emit({'type': 'blocked', 'blocked_user_id': 'other'});
      expect(chat.unavailable, isTrue);
      expect(chat.messages, isEmpty);
      expect(chat.threads, isEmpty);
      expect(await chat.send('Hello'), isFalse);
      socket.emit({'type': 'message', 'message': messageJson()});
      expect(chat.messages, isEmpty);
    },
  );

  test('late history cannot restore messages after a block', () async {
    final delayed = Completer<ChatHistory>();
    api.onHistory = (_, __) => delayed.future;
    final open = chat.openThread(testThread);
    socket.emit({'type': 'blocked', 'blocked_user_id': 'other'});
    delayed.complete(ChatHistory([ChatMessage.fromJson(messageJson())], null));
    await open;
    expect(chat.messages, isEmpty);
    expect(chat.unavailable, isTrue);
  });

  test('blurred and unknown moderation states fail closed', () {
    for (final status in ['blurred', 'pending', 'rejected', 'future-status']) {
      final message = ChatMessage.fromJson(
        messageJson(status: status, body: 'hidden content'),
      );
      expect(message.isVisible, isFalse);
      expect(message.displayBody, isNot(contains('hidden content')));
    }
  });

  test('only an open visible loaded conversation is marked read', () async {
    socket.emit({'type': 'connected'});
    expect(socket.frames, isEmpty);
    await chat.openThread(testThread);
    expect(socket.frames.where((f) => f['type'] == 'read'), hasLength(1));
    chat.setForeground(false);
    expect(socket.disconnects, 1);
    final count = socket.frames.length;
    socket.emit({'type': 'message', 'message': messageJson()});
    expect(socket.frames, hasLength(count));
  });

  test(
    'an authentication failure delegates sign-out without exposing tokens',
    () async {
      chat.dispose();
      var expired = false;
      chat = ChatController(
        api: api,
        userId: 'me',
        socket: FakeChatSocket(),
        onSessionExpired: () => expired = true,
      );
      api.onHistory = (_, __) async => throw const ApiException(
        statusCode: 401,
        code: 'invalid_token',
        message: 'Session expired.',
      );
      await chat.openThread(testThread);
      expect(expired, isTrue);
      expect(chat.historyError, 'Session expired.');
    },
  );

  test('dispose safely ignores history that finishes later', () async {
    final delayed = Completer<ChatHistory>();
    api.onHistory = (_, __) => delayed.future;
    final open = chat.openThread(testThread);
    chat.dispose();
    // Replace the disposed fixture so teardown remains valid.
    chat = ChatController(
      api: FakeChatApi(),
      userId: 'me',
      socket: FakeChatSocket(),
    );
    delayed.complete(const ChatHistory([], null));
    await open;
  });
}
