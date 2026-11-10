import 'dart:async';
import 'dart:convert';

import 'package:beef/api/auth_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/auth/auth_controller.dart';
import 'package:beef/models/auth_tokens.dart';
import 'package:beef/models/profile.dart';
import 'package:beef/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

class NewSessionApi extends AuthApi {
  NewSessionApi(ApiClient client) : super(client);
  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async => const AuthResult(
    user: User(id: 'new-adult', email: 'new@example.invalid'),
    tokens: AuthTokens(accessToken: 'new-access', refreshToken: 'new-refresh'),
  );
  @override
  Future<Profile> me() async => const Profile(id: 'new-adult');
}

void main() {
  for (final successfulRefresh in [true, false]) {
    test(
      'late ${successfulRefresh ? "successful" : "failed"} refresh leaves newer account tokens untouched',
      () async {
        final tokens = MemoryTokens();
        final refreshStarted = Completer<void>();
        final refreshReply = Completer<http.Response>();
        var protectedCalls = 0;
        final client = ApiClient(
          baseUrl: 'https://example.invalid',
          tokenStore: tokens,
          httpClient: MockClient((request) async {
            if (request.url.path == '/api/refresh') {
              refreshStarted.complete();
              return refreshReply.future;
            }
            protectedCalls++;
            return protectedCalls == 1
                ? http.Response('{"error":"expired"}', 401)
                : http.Response('{"ok":true}', 200);
          }),
        );
        final auth = AuthController(
          api: NewSessionApi(client),
          tokenStore: tokens,
        );
        addTearDown(auth.dispose);
        addTearDown(client.close);
        final request = client.post(
          '/api/profile',
          body: {'bio': 'old account edit'},
        );
        final requestCheck = expectLater(request, throwsA(isA<ApiException>()));
        await refreshStarted.future;
        await auth.signOut();
        await auth.login(email: 'new@example.invalid', password: 'test');
        refreshReply.complete(
          successfulRefresh
              ? http.Response(
                  jsonEncode({
                    'accessToken': 'old-rotated',
                    'refreshToken': 'old-refresh-rotated',
                  }),
                  200,
                )
              : http.Response('{"error":"expired"}', 401),
        );
        await requestCheck;
        expect(tokens.access, 'new-access');
        expect(tokens.refresh, 'new-refresh');
        expect(
          protectedCalls,
          1,
          reason: 'Never replay old account writes under a new session',
        );
      },
    );
  }

  test('late refresh cannot restore credentials after sign-out', () async {
    final tokens = MemoryTokens();
    final refreshStarted = Completer<void>();
    final refreshReply = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'https://example.invalid',
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/refresh') {
          refreshStarted.complete();
          return refreshReply.future;
        }
        return http.Response('{"error":"expired"}', 401);
      }),
    );
    final auth = AuthController(api: NewSessionApi(client), tokenStore: tokens);
    addTearDown(auth.dispose);
    addTearDown(client.close);
    final requestCheck = expectLater(
      client.get('/api/me'),
      throwsA(isA<ApiException>()),
    );
    await refreshStarted.future;
    await auth.signOut();
    refreshReply.complete(
      http.Response(
        '{"accessToken":"old-rotated","refreshToken":"old-refresh-rotated"}',
        200,
      ),
    );
    await requestCheck;
    expect(tokens.access, isNull);
    expect(tokens.refresh, isNull);
  });

  test('protected response from an old session is not returned after account change', () async {
    final tokens = MemoryTokens();
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'https://example.invalid',
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        started.complete();
        return reply.future;
      }),
    );
    final auth = AuthController(api: NewSessionApi(client), tokenStore: tokens);
    addTearDown(auth.dispose);
    addTearDown(client.close);
    final requestCheck = expectLater(
      client.get('/api/profile'),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await auth.signOut();
    await auth.login(email: 'new@example.invalid', password: 'test');
    reply.complete(http.Response('{"bio":"old account private profile"}', 200));
    await requestCheck;
  });
}
