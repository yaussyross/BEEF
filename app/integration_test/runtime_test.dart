import 'package:beef/api/chat_api.dart';
import 'package:beef/api/token_store.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:beef/chat/chat_scope.dart';
import 'package:beef/models/chat_message.dart';
import 'package:beef/screens/conversation_screen.dart';
import 'package:beef/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android keystore roundtrip uses platform plugin and clears test tokens', (tester) async {
    const store = SecureTokenStore();
    await store.clear();
    await store.writeTokens(accessToken: 'synthetic-runtime-access', refreshToken: 'synthetic-runtime-refresh');
    expect(await store.readAccessToken(), 'synthetic-runtime-access');
    expect(await store.readRefreshToken(), 'synthetic-runtime-refresh');
    await store.clear();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });
  testWidgets('Android chat renders moderation, native input, retry and block with controlled fixtures', (tester) async {
    final api = FakeChatApi();
    final socket = FakeChatSocket();
    final chat = ChatController(api: api, userId: 'me', socket: socket);
    api.onHistory = (_, __) async => ChatHistory([
      ChatMessage.fromJson(messageJson(status: 'blurred', body: 'synthetic hidden fixture')),
    ], null);
    api.onSend = (_, __, ___) async => throw StateError('synthetic offline');
    await tester.pumpWidget(ChatScope(controller: chat, child: MaterialApp(theme: BeefTheme.dark,
      home: const ConversationScreen(thread: testThread))));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('synthetic hidden fixture'), findsNothing);
    expect(find.text('Message hidden for safety review.'), findsOneWidget);
    await binding.takeScreenshot('01-chat-moderation');
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Synthetic emulator greeting');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('02-chat-input');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsOneWidget);
    await binding.takeScreenshot('03-chat-retry');
    api.onSend = null;
    await tester.tap(find.text('Retry message'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsNothing);
    expect(api.sentIds, hasLength(2));
    expect(api.sentIds.first, api.sentIds.last);
    socket.emit({'type': 'blocked', 'blocked_user_id': 'other'});
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Synthetic emulator greeting'), findsNothing);
    expect(find.text('This conversation is unavailable.'), findsWidgets);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('04-chat-blocked');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    chat.dispose();
  });
}
