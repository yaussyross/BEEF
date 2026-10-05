import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/auth_api.dart';
import '../api/token_store.dart';
import '../models/profile.dart';
import '../models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Single source of truth for the signed-in state. Rebuilds listeners on every
/// transition; the UI reads it through `AuthScope`.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore});

  final AuthApi api;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.unknown;
  Profile? _profile;
  User? _user;

  AuthStatus get status => _status;
  Profile? get profile => _profile;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Rehydrate the session from the secure keystore. Called once at startup;
  /// the splash screen shows while `status` is `unknown`.
  Future<void> restore() async {
    try {
      final String? access = await tokenStore.readAccessToken();
      if (access == null || access.isEmpty) {
        _setUnauthenticated();
        notifyListeners();
        return;
      }
      // A stored-but-expired token triggers the client's refresh-on-401, which
      // either re-issues or clears tokens. Any failure here (bad token, account
      // disabled, or a network error) signs out for a clean cold-start path;
      // fine for v1 — the keystore round-trip is the only thing at stake.
      final Profile profile = await api.me();
      _profile = profile;
      _user = User(id: profile.id, email: profile.email ?? '');
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      await _signOutQuietly();
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String birthdate,
  }) async {
    final AuthResult result = await api.register(
      email: email,
      password: password,
      birthdate: birthdate,
    );
    await _applySession(result);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final AuthResult result = await api.login(
      email: email,
      password: password,
    );
    await _applySession(result);
  }

  Future<void> signOut() async {
    await _signOutQuietly();
    notifyListeners();
  }

  Future<void> _applySession(AuthResult result) async {
    await tokenStore.writeTokens(
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
    );
    _user = result.user;
    _status = AuthStatus.authenticated;
    notifyListeners();

    // Best-effort fetch of the richer profile; don't fail the login if this
    // network call hiccups — the user is already in.
    try {
      _profile = await api.me();
    } catch (_) {
      _profile = null;
    }
    notifyListeners();
  }

  Future<void> _signOutQuietly() async {
    await tokenStore.clear();
    _user = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
  }

  void _setUnauthenticated() {
    _user = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
  }
}
