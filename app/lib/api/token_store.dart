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
