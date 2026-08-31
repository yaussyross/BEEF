import 'dart:async';

import '../models/auth_tokens.dart';
import '../models/profile.dart';
import '../models/user.dart';
import 'http_client.dart';

/// A successful register/login: the minimal user plus a token pair.
class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        tokens: AuthTokens.fromJson(json),
      );
}

/// Auth endpoints consumed by the client. Mirrors the backend route files
/// `register.ts`, `login.ts`, `refresh.ts`, `me.ts` exactly.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// POST /api/register  { email, password, birthdate (YYYY-MM-DD) }
  /// → 201 { user, accessToken, refreshToken }. The server re-rejects <18 too.
  Future<AuthResult> register({
    required String email,
    required String password,
    required String birthdate,
  }) async {
    final Map<String, dynamic> data = await _client.post(
      '/api/register',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'birthdate': birthdate,
      },
      authenticated: false,
    );
    return AuthResult.fromJson(data);
  }

  /// POST /api/login  { email, password }
  /// → 200 { user, accessToken, refreshToken }.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic> data = await _client.post(
      '/api/login',
      body: <String, dynamic>{'email': email, 'password': password},
      authenticated: false,
    );
    return AuthResult.fromJson(data);
  }

  /// POST /api/refresh  { refreshToken }
  /// → 200 { accessToken, refreshToken } (no user). Also used internally by the
  /// client's refresh-on-401 flow; exposed here for completeness.
  Future<AuthTokens> refresh(String refreshToken) async {
    final Map<String, dynamic> data = await _client.post(
      '/api/refresh',
      body: <String, dynamic>{'refreshToken': refreshToken},
      authenticated: false,
    );
    return AuthTokens.fromJson(data);
  }

  /// GET /api/me  (Bearer) → 200 { user: { id, email, status, display_name, … } }.
  Future<Profile> me() async {
    final Map<String, dynamic> data = await _client.get('/api/me');
    return Profile.fromJson(data['user'] as Map<String, dynamic>);
  }
}
