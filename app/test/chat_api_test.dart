import 'dart:convert';

import 'package:beef/api/chat_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/models/chat_thread.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

void main() {
  test(
    'history preserves opaque cursor and sends auth only in header',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        tokenStore: MemoryTokens(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/threads/thread-a/messages');
          expect(
            request.url.queryParameters['cursor'],
            '2026-10-06 12:00:00+00|uuid',
          );
          expect(request.headers['Authorization'], 'Bearer test-access');
          expect(request.url.toString(), isNot(contains('test-access')));
          return http.Response(
            jsonEncode({
              'messages': [messageJson()],
              'next_cursor': null,
            }),
            200,
          );
        }),
      );
      final page = await ChatApi(client)
          .history('thread-a', cursor: '2026-10-06 12:00:00+00|uuid');
      expect(page.messages.single.body, 'Hello');
      client.close();
    },
  );

  test('create-thread shape accepts absent last message and unread count', () {
    final thread = ChatThread.fromJson({
      'id': 'id',
      'other_user_id': 'other',
      'other_display_name': null,
    });
    expect(thread.unreadCount, 0);
    expect(thread.lastMessage, isNull);
    expect(thread.displayName, 'A fellow cut');
  });

  test('HTTP fallback reuses idempotency id after token refresh', () async {
    final tokens = MemoryTokens();
    var requests = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'rotated-test',
              'refreshToken': 'rotated-refresh',
            }),
            200,
          );
        }
        requests++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_message_id'], 'stable-id');
        if (requests == 1) {
          return http.Response(
            jsonEncode({'error': 'expired', 'message': 'Expired'}),
            401,
          );
        }
        expect(request.headers['Authorization'], 'Bearer rotated-test');
        return http.Response(
          jsonEncode({'message': messageJson(client: 'stable-id')}),
          200,
        );
      }),
    );
    await ChatApi(client).send('thread-a', 'stable-id', 'Hello');
    expect(requests, 2);
    client.close();
  });
}
