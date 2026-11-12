import 'dart:async';

import 'package:beef/api/auth_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/auth/auth_controller.dart';
import 'package:beef/models/auth_tokens.dart';
import 'package:beef/models/profile.dart';
import 'package:beef/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_helpers.dart';

class SessionApi extends AuthApi {
  SessionApi(MemoryTokens store)
    : super(ApiClient(baseUrl: 'https://example.invalid', tokenStore: store));
  final loginResult = Completer<AuthResult>();
  final loginStarted = Completer<void>();
  final profileResult = Completer<Profile>();
  final profileStarted = Completer<void>();
  @override
  Future<AuthResult> login({required String email, required String password}) {
    loginStarted.complete();
    return loginResult.future;
  }

  @override
  Future<Profile> me() {
    if (!profileStarted.isCompleted) profileStarted.complete();
    return profileResult.future;
  }
}

class DelayedTokens extends MemoryTokens {
  final writeStarted = Completer<void>();
  final allowWrite = Completer<void>();
  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    writeStarted.complete();
    await allowWrite.future;
    await super.writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

const session = AuthResult(
  user: User(id: 'adult-a', email: 'adult-a@example.invalid'),
  tokens: AuthTokens(accessToken: 'access-a', refreshToken: 'refresh-a'),
);

void main() {
  test('late login response cannot resurrect a signed-out session', () async {
    final store = MemoryTokens();
    final api = SessionApi(store);
    final auth = AuthController(api: api, tokenStore: store);
    addTearDown(auth.dispose);
    final login = auth.login(
      email: 'adult-a@example.invalid',
      password: 'test',
    );
    await api.loginStarted.future;
    await auth.signOut();
    api.profileResult.complete(const Profile(id: 'adult-a'));
    api.loginResult.complete(session);
    await login;
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
    expect(auth.profile, isNull);
    expect(await store.readAccessToken(), isNull);
  });

  test(
    'late profile response does not repopulate signed-out private data',
    () async {
      final store = MemoryTokens();
      final api = SessionApi(store);
      final auth = AuthController(api: api, tokenStore: store);
      addTearDown(auth.dispose);
      api.loginResult.complete(session);
      final login = auth.login(
        email: 'adult-a@example.invalid',
        password: 'test',
      );
      await api.profileStarted.future;
      await auth.signOut();
      api.profileResult.complete(const Profile(id: 'adult-a', bio: 'private'));
      await login;
      expect(auth.profile, isNull);
      expect(auth.user, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
    },
  );

  test('late restore response cannot resurrect a signed-out session', () async {
    final store = MemoryTokens();
    final api = SessionApi(store);
    final auth = AuthController(api: api, tokenStore: store);
    addTearDown(auth.dispose);
    final restore = auth.restore();
    await api.profileStarted.future;
    await auth.signOut();
    api.profileResult.complete(const Profile(id: 'adult-a'));
    await restore;
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.profile, isNull);
  });

  test('disposed controller ignores a pending login result', () async {
    final store = MemoryTokens();
    final api = SessionApi(store);
    final auth = AuthController(api: api, tokenStore: store);
    final login = auth.login(
      email: 'adult-a@example.invalid',
      password: 'test',
    );
    await api.loginStarted.future;
    auth.dispose();
    api.profileResult.complete(const Profile(id: 'adult-a'));
    api.loginResult.complete(session);
    await expectLater(login, completes);
    // Starting a new login may clear prior credentials; disposal must never
    // allow its delayed response to persist the new account's credentials.
    expect(await store.readAccessToken(), isNot('access-a'));
  });

  test('stale restore failure does not sign out a newer login', () async {
    final store = MemoryTokens();
    final api = SessionApi(store);
    final auth = AuthController(api: api, tokenStore: store);
    addTearDown(auth.dispose);
    final restore = auth.restore();
    await api.profileStarted.future;
    api.loginResult.complete(session);
    final login = auth.login(
      email: 'adult-a@example.invalid',
      password: 'test',
    );
    // Allow the login token write and authenticated state to settle before the
    // original restore request fails. Both profile fetches share this failure.
    await Future<void>.delayed(Duration.zero);
    api.profileResult.completeError(StateError('old request failed'));
    await Future.wait([restore, login]);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.id, 'adult-a');
    expect(await store.readAccessToken(), 'access-a');
  });

  test(
    'sign-out clears an already-started token write after it finishes',
    () async {
      final store = DelayedTokens();
      final api = SessionApi(store);
      final auth = AuthController(api: api, tokenStore: store);
      addTearDown(auth.dispose);
      api.loginResult.complete(session);
      api.profileResult.complete(const Profile(id: 'adult-a'));
      final login = auth.login(
        email: 'adult-a@example.invalid',
        password: 'test',
      );
      await store.writeStarted.future;
      final signOut = auth.signOut();
      store.allowWrite.complete();
      await Future.wait([login, signOut]);
      expect(await store.readAccessToken(), isNull);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.profile, isNull);
    },
  );
}
