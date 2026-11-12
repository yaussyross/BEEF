import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where auth tokens live. Abstract so tests (or a future platform swap) can
/// substitute an in-memory store without touching the secure-storage plugin.
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

/// Coordinates token mutations across authentication and HTTP refresh for the
/// same store. A generation represents one session intent, not one request.
/// All writers must use this coordinator so sign-out clears even an in-flight
/// secure-keystore write before another session can use its credentials.
class TokenSession {
  TokenSession._(this._store);

  static final Expando<TokenSession> _sessions = Expando<TokenSession>();

  static TokenSession forStore(TokenStore store) =>
      _sessions[store] ??= TokenSession._(store);

  final TokenStore _store;
  int _generation = 0;
  Future<void> _tail = Future<void>.value();

  int get generation => _generation;
  int beginSession() => ++_generation;
  bool isCurrent(int generation) => generation == _generation;
  Future<void> get settled => _tail;

  Future<bool> mutate(int generation, Future<void> Function() action) {
    final operation = _tail.then((_) async {
      if (!isCurrent(generation)) return false;
      await action();
      return isCurrent(generation);
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  /// Once sign-out is requested, its queued deletion must run even if a newer
  /// login starts before the previous keystore write finishes.
  Future<void> clear() {
    final operation = _tail.then((_) => _store.clear());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}

/// Platform secure keystore (iOS Keychain / Android EncryptedSharedPreferences)
/// backed by `flutter_secure_storage`. Tokens never touch shared prefs.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  static const String _accessKey = 'beef.accessToken';
  static const String _refreshKey = 'beef.refreshToken';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
