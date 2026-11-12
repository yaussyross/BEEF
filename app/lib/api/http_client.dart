import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_store.dart';

/// A backend error mapped to its `{ error, message }` JSON shape. Mirrors
/// `errorResponse()` in the backend's `src/lib/http.ts` — every non-2xx carries
/// an `error` code plus a human-readable `message`.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;

  /// Machine code, e.g. `invalid_credentials`, `email_taken`, `underage`.
  final String code;

  /// Human-readable copy straight from the backend (already on-brand).
  final String message;

  factory ApiException.fromResponse(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    final code = body?['error'] as String? ?? 'unknown_error';
    final message = body?['message'] as String? ?? 'Something went wrong.';
    return ApiException(statusCode: statusCode, code: code, message: message);
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Thin JSON HTTP client with:
///  - a shared base URL + `Authorization: Bearer <jwt>` header,
///  - consistent JSON encode/decode,
///  - automatic refresh-on-401 (single retry), then token clear on definitive rejection so
///    the caller can route the user back to login.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  final Duration requestTimeout;
  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _http;

  /// Guards against concurrent refresh storms: only one refresh in flight.
  Future<bool>? _refreshing;
  int? _refreshingGeneration;

  TokenSession get _session => TokenSession.forStore(tokenStore);

  void _requireCurrent(int generation) {
    if (!_session.isCurrent(generation)) {
      throw const ApiException(
        statusCode: 409,
        code: 'session_changed',
        message: 'The signed-in account changed. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send('PUT', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send('DELETE', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final int generation = _session.generation;
    if (authenticated) {
      await _session.settled;
      _requireCurrent(generation);
    }
    final Uri uri = Uri.parse('$baseUrl$path');
    String? accessToken = authenticated
        ? await tokenStore.readAccessToken()
        : null;

    if (authenticated) _requireCurrent(generation);
    http.Response response = await _perform(method, uri, body, accessToken);
    if (authenticated) _requireCurrent(generation);

    // Refresh once on 401 for protected calls. register/login/refresh are not
    // authenticated and never enter this path, so no recursive refresh.
    if (authenticated && response.statusCode == 401 && accessToken != null) {
      final bool refreshed = await _refreshTokens(generation);
      _requireCurrent(generation);
      if (refreshed) {
        await _session.settled;
        _requireCurrent(generation);
        accessToken = await tokenStore.readAccessToken();
        _requireCurrent(generation);
        response = await _perform(method, uri, body, accessToken);
      }
    }

    if (authenticated) _requireCurrent(generation);
    return _decode(response);
  }

  Future<http.Response> _perform(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
    String? accessToken,
  ) async {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final String? token = accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final String? encoded = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers).timeout(requestTimeout);
      case 'POST':
        return _http.post(uri, headers: headers, body: encoded).timeout(requestTimeout);
      case 'PUT':
        return _http.put(uri, headers: headers, body: encoded).timeout(requestTimeout);
      case 'DELETE':
        return _http.delete(uri, headers: headers, body: encoded).timeout(requestTimeout);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  /// Rotate the token pair using the stored refresh token. Returns true when a
  /// new pair was persisted. Transient errors retain credentials without replay.
  Future<bool> _refreshTokens(int generation) async {
    final Future<bool>? inFlight = _refreshing;
    if (inFlight != null && _refreshingGeneration == generation) {
      return inFlight;
    }

    final Future<bool> future = _doRefresh(generation);
    _refreshing = future;
    _refreshingGeneration = generation;
    try {
      return await future;
    } finally {
      // An old account's completion must not erase a newer refresh guard.
      if (identical(_refreshing, future)) {
        _refreshing = null;
        _refreshingGeneration = null;
      }
    }
  }

  Future<bool> _doRefresh(int generation) async {
    await _session.settled;
    if (!_session.isCurrent(generation)) return false;
    final String? refreshToken = await tokenStore.readRefreshToken();
    if (!_session.isCurrent(generation)) return false;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _session.mutate(generation, tokenStore.clear);
      return false;
    }

    final Uri uri = Uri.parse('$baseUrl/api/refresh');
    try {
      final http.Response response = await _perform(
        'POST',
        uri,
        <String, dynamic>{'refreshToken': refreshToken},
        null,
      );
      if (!_session.isCurrent(generation)) return false;
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _session.mutate(generation, tokenStore.clear);
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException('Refresh unavailable');
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid refresh response');
      }
      final String? newAccess = decoded['accessToken'] as String?;
      final String? newRefresh = decoded['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null || newAccess.isEmpty || newRefresh.isEmpty) {
        throw const FormatException('Missing refresh tokens');
      }
      return await _session.mutate(
        generation,
        () => tokenStore.writeTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        ),
      );
    } catch (_) {
      if (!_session.isCurrent(generation)) return false;
      throw const ApiException(statusCode: 503, code: 'refresh_unavailable',
        message: 'Unable to refresh your session. Please try again later.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? json;
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json ?? const <String, dynamic>{};
    }
    throw ApiException.fromResponse(response.statusCode, json);
  }

  void close() => _http.close();
}
