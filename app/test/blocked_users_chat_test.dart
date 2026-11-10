import 'dart:convert';

import 'package:beef/api/http_client.dart';
import 'package:beef/api/safety_api.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:beef/chat/chat_scope.dart';
import 'package:beef/screens/blocked_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'unblock ${succeeds ? "success reconciles" : "failure preserves"} chat block',
      (tester) async {
        final chat = ChatController(
          api: FakeChatApi(),
          userId: 'me',
          socket: FakeChatSocket(),
        );
        addTearDown(chat.dispose);
        await chat.openThread(testThread);
        chat.confirmBlock('other');
        final client = ApiClient(
          baseUrl: 'https://example.test',
          tokenStore: MemoryTokens(),
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'users': [
                    {'user_id': 'other', 'blocked_at': '2026-11-10'},
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({'ok': succeeds, 'blocked': !succeeds}),
              200,
            );
          }),
        );
        addTearDown(client.close);
        await tester.pumpWidget(
          ChatScope(
            controller: chat,
            child: MaterialApp(
              home: BlockedUsersScreen(api: SafetyApi(client)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unblock'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm unblock'));
        await tester.pumpAndSettle();
        expect(chat.unavailable, !succeeds);
        expect(
          find.text('No blocked users.'),
          succeeds ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
