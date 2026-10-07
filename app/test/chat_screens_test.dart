import 'package:beef/chat/chat_controller.dart';
import 'package:beef/chat/chat_scope.dart';
import 'package:beef/models/chat_message.dart';
import 'package:beef/api/chat_api.dart';
import 'package:beef/screens/conversation_screen.dart';
import 'package:beef/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_helpers.dart';

void main() {
  late FakeChatApi api;
  late FakeChatSocket socket;
  late ChatController chat;
  setUp(() {
    api = FakeChatApi();
    socket = FakeChatSocket();
    chat = ChatController(api: api, userId: 'me', socket: socket);
  });
  tearDown(() => chat.dispose());

  Widget app() => ChatScope(
    controller: chat,
    child: MaterialApp(
      theme: BeefTheme.dark,
      home: const ConversationScreen(thread: testThread),
    ),
  );

  testWidgets(
    'hidden message body never enters the rendered text or semantics',
    (tester) async {
      api.onHistory = (_, __) async => ChatHistory([
        ChatMessage.fromJson(
          messageJson(status: 'blurred', body: 'private moderation text'),
        ),
      ], null);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('private moderation text'), findsNothing);
      expect(find.text('Message hidden for safety review.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('send clears draft and a failed message remains retryable', (
    tester,
  ) async {
    api.onSend = (_, __, ___) async => throw StateError('offline');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('Retry message'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    api.onSend = null;
    await tester.tap(find.text('Retry message'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsNothing);
    expect(api.sentIds, hasLength(2));
    expect(api.sentIds.first, api.sentIds.last);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('blocked conversation removes composer and message content', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    socket.emit({
      'type': 'message',
      'message': messageJson(body: 'Existing text'),
    });
    await tester.pump();
    expect(find.text('Existing text'), findsOneWidget);
    socket.emit({'type': 'blocked', 'blocked_user_id': 'other'});
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Existing text'), findsNothing);
    expect(find.text('This conversation is unavailable.'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('narrow screen with keyboard has no layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'A multiline\nmessage\nwith room\nto send',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Back disposes conversation state and stale messages stay off inbox route',
    (tester) async {
      await tester.pumpWidget(
        ChatScope(
          controller: chat,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ConversationScreen(thread: testThread),
                    ),
                  ),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
      expect(chat.activeThread?.id, testThread.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(chat.activeThread, isNull);
      expect(find.text('Open chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
