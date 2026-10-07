import 'dart:async';

import 'package:beef/api/chat_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:beef/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_helpers.dart';

class _OfflineSocket extends FakeChatSocket {
  @override
  Future<void> connect(String baseUrl, String token) async {}
}

void main() {
  test(
    'a blocked history response notifies the visible unavailable state',
    () async {
      final api = FakeChatApi();
      final chat = ChatController(
        api: api,
        userId: 'me',
        socket: FakeChatSocket(),
      );
      addTearDown(chat.dispose);
      api.onHistory = (_, __) async => throw const ApiException(
        statusCode: 403,
        code: 'blocked',
        message: 'This conversation is unavailable.',
      );
      var observedUnavailable = false;
      var observedLoading = false;
      chat.addListener(() {
        observedUnavailable = chat.unavailable;
        observedLoading = chat.historyLoading;
      });

      await chat.openThread(testThread);

      expect(chat.unavailable, isTrue);
      expect(observedUnavailable, isTrue);
      expect(observedLoading, isFalse);
    },
  );

  test(
    'reconnect waits for catch-up before marking new messages read',
    () async {
      final api = FakeChatApi();
      final socket = FakeChatSocket();
      final chat = ChatController(api: api, userId: 'me', socket: socket);
      addTearDown(chat.dispose);
      await chat.openThread(testThread);
      socket.emit({'type': 'connected'});
      await Future<void>.delayed(Duration.zero);
      socket.emit({'type': 'disconnected'});
      socket.frames.clear();
      final catchUp = Completer<ChatHistory>();
      api.onHistory = (_, __) => catchUp.future;

      socket.emit({'type': 'connected'});
      final prematureReads = socket.frames
          .where((frame) => frame['type'] == 'read')
          .toList();
      catchUp.complete(
        ChatHistory([ChatMessage.fromJson(messageJson())], null),
      );
      await Future<void>.delayed(Duration.zero);

      expect(prematureReads, isEmpty);
      expect(
        socket.frames.where((frame) => frame['type'] == 'read'),
        hasLength(1),
      );
    },
  );

  test(
    'reconnect during older-page loading still fetches fresh history',
    () async {
      final api = FakeChatApi();
      final socket = FakeChatSocket();
      final chat = ChatController(api: api, userId: 'me', socket: socket);
      addTearDown(chat.dispose);
      api.onHistory = (_, __) async =>
          ChatHistory([ChatMessage.fromJson(messageJson())], 'older|id');
      await chat.openThread(testThread);
      socket.emit({'type': 'connected'});
      await Future<void>.delayed(Duration.zero);
      socket.frames.clear();
      final olderPage = Completer<ChatHistory>();
      final catchUp = Completer<ChatHistory>();
      api.onHistory = (_, cursor) =>
          cursor == null ? catchUp.future : olderPage.future;
      final loadingOlder = chat.loadOlder();

      socket.emit({'type': 'disconnected'});
      socket.emit({'type': 'connected'});
      olderPage.complete(const ChatHistory([], null));
      await loadingOlder;
      final prematureReads = socket.frames
          .where((frame) => frame['type'] == 'read')
          .toList();
      catchUp.complete(
        ChatHistory([ChatMessage.fromJson(messageJson(id: 'newest'))], null),
      );
      await Future<void>.delayed(Duration.zero);

      expect(prematureReads, isEmpty);
      expect(chat.messages.any((message) => message.id == 'newest'), isTrue);
    },
  );

  testWidgets('REST polling keeps missed older messages reachable', (
    tester,
  ) async {
    final api = FakeChatApi();
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: _OfflineSocket(),
      pollInterval: const Duration(seconds: 1),
    );
    try {
      await chat.start();
      await chat.openThread(testThread);
      expect(chat.hasMore, isFalse);
      final latest = List.generate(
        50,
        (index) => ChatMessage.fromJson(
          messageJson(id: 'new-$index', client: 'client-new-$index'),
        ),
      );
      final missed = ChatMessage.fromJson(
        messageJson(id: 'missed', client: 'client-missed'),
      );
      api.onHistory = (_, cursor) async => cursor == null
          ? ChatHistory(latest, 'older|id')
          : ChatHistory([missed], null);

      await tester.pump(const Duration(seconds: 1));

      expect(chat.messages, hasLength(50));
      expect(chat.hasMore, isTrue);
      await chat.loadOlder();
      expect(chat.messages, hasLength(51));
      expect(chat.messages.any((message) => message.id == 'missed'), isTrue);
    } finally {
      chat.dispose();
    }
  });

  for (final startsEmpty in [false, true]) {
    testWidgets(
      'a REST send cannot hide a history gap (initially empty: $startsEmpty)',
      (tester) async {
        final api = FakeChatApi();
        final chat = ChatController(
          api: api,
          userId: 'me',
          socket: _OfflineSocket(),
          pollInterval: const Duration(seconds: 1),
        );
        try {
          api.onHistory = (_, __) async => startsEmpty
              ? const ChatHistory([], null)
              : ChatHistory([
                  ChatMessage.fromJson(messageJson(id: 'original')),
                ], null);
          await chat.start();
          await chat.openThread(testThread);
          api.onSend = (thread, clientId, body) async => ChatMessage.fromJson(
            messageJson(id: 'my-latest', sender: 'me', client: clientId),
          );
          await chat.send('My latest message');
          final ownLatest = chat.messages.singleWhere(
            (message) => message.id == 'my-latest',
          );
          final latest = [
            ownLatest,
            ...List.generate(
              49,
              (index) => ChatMessage.fromJson(
                messageJson(id: 'new-$index', client: 'client-new-$index'),
              ),
            ),
          ];
          api.onHistory = (_, cursor) async => cursor == null
              ? ChatHistory(latest, 'older|id')
              : ChatHistory([
                  ChatMessage.fromJson(messageJson(id: 'missed')),
                ], null);

          await tester.pump(const Duration(seconds: 1));

          expect(chat.hasMore, isTrue);
          await chat.loadOlder();
          expect(
            chat.messages.any((message) => message.id == 'missed'),
            isTrue,
          );
        } finally {
          chat.dispose();
        }
      },
    );
  }
}
