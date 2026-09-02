// MTA2_CONTRACT: STATIC_PRIVILEGED_API_KEY_IN_APP = ZERO
// QUAL_CREDENTIAL_IN_RELEASE = ZERO
// Session tokens are held in FlutterSecureStorage and NEVER written to logs.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/config/environment.dart';
import '../auth_models.dart';

class AuthException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;

  const AuthException(this.statusCode, this.message, {this.errorCode});

  @override
  String toString() =>
      'AuthException($statusCode${errorCode != null ? '/$errorCode' : ''}): $message';
}

class AuthService {
  static const String _sessionKey = 'pv_customer_session';
  static const Duration _refreshThreshold = Duration(minutes: 5);

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final String _baseUrl;

  AuthService({
    FlutterSecureStorage? storage,
    http.Client? client,
    String? baseUrl,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<CustomerSession> signIn(String email, String password) async {
    final body = jsonEncode({'email': email, 'password': password});
    final response = await _post('/api/v1/customer/auth/sign-in', body);
    final session = CustomerSession.fromJson(response);
    await _storeSession(session);
    return session;
  }

  Future<CustomerSession> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    final response = await _post('/api/v1/customer/auth/sign-up', body);
    final session = CustomerSession.fromJson(response);
    await _storeSession(session);
    return session;
  }

  Future<void> signOut() async {
    final session = await getStoredSession();
    if (session != null) {
      try {
        await _client
            .post(
              Uri.parse('$_baseUrl/api/v1/customer/auth/sign-out'),
              headers: {
                'Content-Type': 'application/json',
                // Token value intentionally not logged anywhere.
                'Authorization': 'Bearer ${session.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // Best-effort: always clear local session regardless of network.
      }
    }
    await _clearSession();
  }

  Future<CustomerSession> refreshSession() async {
    final stored = await getStoredSession();
    if (stored == null) {
      throw const AuthException(401, 'No session to refresh.',
          errorCode: 'NO_SESSION');
    }
    final body = jsonEncode({'refresh_token': stored.refreshToken});
    final response = await _post('/api/v1/customer/auth/refresh', body);
    final updated = stored.copyWith(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
      expiresAt:
          DateTime.parse(response['expires_at'] as String).toUtc(),
    );
    await _storeSession(updated);
    return updated;
  }

  /// Returns the stored session, auto-refreshing if it is near expiry.
  /// Returns null when no session exists or it cannot be refreshed.
  Future<CustomerSession?> getStoredSession() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null) return null;
      final session =
          CustomerSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      if (session.isExpired) {
        // Attempt silent refresh; propagate AuthException on failure.
        try {
          return await _refreshWithRefreshToken(session.refreshToken);
        } on AuthException {
          await _clearSession();
          return null;
        }
      }

      if (session.expiresWithin(_refreshThreshold)) {
        // Near expiry — refresh in the background; return current token now.
        _refreshWithRefreshToken(session.refreshToken).ignore();
      }

      return session;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<CustomerSession> _refreshWithRefreshToken(
      String refreshToken) async {
    final body = jsonEncode({'refresh_token': refreshToken});
    final response = await _post('/api/v1/customer/auth/refresh', body);
    final stored = await getStoredSession();
    final updated = CustomerSession(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
      expiresAt:
          DateTime.parse(response['expires_at'] as String).toUtc(),
      userId: stored?.userId ?? '',
      displayName: stored?.displayName ?? '',
    );
    await _storeSession(updated);
    return updated;
  }

  Future<Map<String, dynamic>> _post(
      String path, String body, {Map<String, String>? extraHeaders}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extraHeaders,
    };

    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AuthException(0, 'Network error: $e', errorCode: 'NETWORK_ERROR');
    }

    if (response.statusCode == 401) {
      String msg = 'Unauthorised.';
      String? code;
      try {
        final err =
            jsonDecode(response.body) as Map<String, dynamic>;
        msg = (err['message'] ?? err['error'] ?? msg).toString();
        code = (err['code'] as String?);
      } catch (_) {}
      throw AuthException(401, msg, errorCode: code ?? 'UNAUTHORIZED');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String msg = 'Request failed (${response.statusCode}).';
      String? code;
      try {
        final err =
            jsonDecode(response.body) as Map<String, dynamic>;
        msg = (err['message'] ?? err['error'] ?? msg).toString();
        code = (err['code'] as String?);
      } catch (_) {}
      throw AuthException(response.statusCode, msg, errorCode: code);
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException(
          response.statusCode, 'Unexpected response format.',
          errorCode: 'PARSE_ERROR');
    }
  }

  Future<void> _storeSession(CustomerSession session) async {
    // Encode the session as JSON; the token value is stored in secure storage
    // and MUST NOT appear in any log statement.
    await _storage.write(
        key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> _clearSession() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {}
  }
}
