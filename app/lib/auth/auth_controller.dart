import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/auth_api.dart';
import '../api/token_store.dart';
import '../models/profile.dart';
import '../models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Single source of truth for signed-in state. Stale network completions cannot
/// restore a signed-out session or publish a previous account's private profile.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore})
    : _session = TokenSession.forStore(tokenStore);

  final AuthApi api;
  final TokenStore tokenStore;
  final TokenSession _session;
  bool _disposed = false;

  AuthStatus _status = AuthStatus.unknown;
  Profile? _profile;
  User? _user;

  AuthStatus get status => _status;
  Profile? get profile => _profile;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool _current(int generation) => !_disposed && _session.isCurrent(generation);

  Future<void> restore() async {
    if (_disposed) return;
    final generation = _session.beginSession();
    try {
      await _session.settled;
      if (!_current(generation)) return;
      final access = await tokenStore.readAccessToken();
      if (!_current(generation)) return;
      if (access == null || access.isEmpty) {
        _setUnauthenticated();
        notifyListeners();
        return;
      }
      final profile = await api.me();
      if (!_current(generation)) return;
      _profile = profile;
      _user = User(id: profile.id, email: profile.email ?? '');
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      if (!_current(generation)) return;
      await _session.mutate(generation, tokenStore.clear);
      if (!_current(generation)) return;
      _setUnauthenticated();
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String birthdate,
  }) async {
    if (_disposed) return;
    final generation = _beginLogin();
    await _session.clear();
    if (!_current(generation)) return;
    final result = await api.register(
      email: email,
      password: password,
      birthdate: birthdate,
    );
    await _applySession(result, generation);
  }

  Future<void> login({required String email, required String password}) async {
    if (_disposed) return;
    final generation = _beginLogin();
    await _session.clear();
    if (!_current(generation)) return;
    final result = await api.login(email: email, password: password);
    await _applySession(result, generation);
  }

  int _beginLogin() {
    final generation = _session.beginSession();
    // Switching accounts is an explicit new session, not permission to keep
    // issuing protected requests with the previous account's credentials.
    _setUnauthenticated();
    notifyListeners();
    return generation;
  }

  Future<void> signOut() async {
    if (_disposed) return;
    _session.beginSession();
    _setUnauthenticated();
    notifyListeners();
    // Always finish this queued clear, even if a later login fails. The queue
    // orders it after already-started writes and before later session writes.
    await _session.clear();
  }

  Future<void> _applySession(AuthResult result, int generation) async {
    if (!_current(generation)) return;
    final stored = await _session.mutate(
      generation,
      () => tokenStore.writeTokens(
        accessToken: result.tokens.accessToken,
        refreshToken: result.tokens.refreshToken,
      ),
    );
    if (!stored || !_current(generation)) return;
    _user = result.user;
    _profile = null;
    _status = AuthStatus.authenticated;
    notifyListeners();

    try {
      final profile = await api.me();
      if (!_current(generation)) return;
      _profile = profile;
    } catch (_) {
      if (!_current(generation)) return;
      _profile = null;
    }
    notifyListeners();
  }

  void _setUnauthenticated() {
    _user = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
  }

  @override
  void dispose() {
    _disposed = true;
    _session.beginSession();
    super.dispose();
  }
}
