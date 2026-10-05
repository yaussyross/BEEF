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

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic>? body) {
    final code = body?['error'] as String? ?? 'unknown_error';
    final message = body?['message'] as String? ?? 'Something went wrong.';
    return ApiException(
      statusCode: statusCode,
      code: code,
      message: message,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Thin JSON HTTP client with:
///  - a shared base URL + `Authorization: Bearer <jwt>` header,
///  - consistent JSON encode/decode,
///  - automatic refresh-on-401 (single retry), then token clear on failure so
///    the caller can route the user back to login.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _http;

  /// Guards against concurrent refresh storms: only one refresh in flight.
  Future<bool>? _refreshing;

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('PUT', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('DELETE', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    String? accessToken = authenticated
        ? await tokenStore.readAccessToken()
        : null;

    http.Response response = await _perform(method, uri, body, accessToken);

    // Refresh once on 401 for protected calls. register/login/refresh are not
    // authenticated and never enter this path, so no recursive refresh.
    if (authenticated && response.statusCode == 401 && accessToken != null) {
      final bool refreshed = await _refreshTokens();
      if (refreshed) {
        accessToken = await tokenStore.readAccessToken();
        response = await _perform(method, uri, body, accessToken);
      }
    }

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
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: encoded);
      case 'PUT':
        return _http.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _http.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  /// Rotate the token pair using the stored refresh token. Returns true when a
  /// new pair was persisted. Clears tokens on failure so callers can route the
  /// user back to login.
  Future<bool> _refreshTokens() async {
    final Future<bool>? inFlight = _refreshing;
    if (inFlight != null) return inFlight;

    final Future<bool> future = _doRefresh();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _doRefresh() async {
    final String? refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await tokenStore.clear();
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await tokenStore.clear();
        return false;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        await tokenStore.clear();
        return false;
      }
      final String? newAccess = decoded['accessToken'] as String?;
      final String? newRefresh = decoded['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) {
        await tokenStore.clear();
        return false;
      }
      await tokenStore.writeTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } catch (_) {
      await tokenStore.clear();
      return false;
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
