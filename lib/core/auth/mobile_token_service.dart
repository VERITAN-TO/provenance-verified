import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/environment.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;
  const ApiException(this.statusCode, this.message, {this.errorCode});
  @override
  String toString() => 'ApiException($statusCode/${errorCode ?? ''}): $message';
}

class MobileTokenService {
  static const String _tokenKey    = 'pv_mobile_token';
  static const String _expiresKey  = 'pv_mobile_expires_at';
  static const String _deviceIdKey = 'pv_mobile_device_id';
  static const Duration _refreshThreshold = Duration(minutes: 30);

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final String _baseUrl;
  final String _tenantId;

  String?   _cachedToken;
  DateTime? _cachedExpiresAt;
  Future<String>? _inflightBootstrap;

  MobileTokenService({
    FlutterSecureStorage? storage,
    http.Client? client,
    String? baseUrl,
    String? tenantId,
  })  : _storage   = storage ?? const FlutterSecureStorage(),
        _client    = client ?? http.Client(),
        _baseUrl   = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _tenantId  = tenantId ?? Env.pvTenantId;

  Future<String> getToken() async {
    if (_cachedToken != null && _cachedExpiresAt != null) {
      final remaining = _cachedExpiresAt!.difference(DateTime.now().toUtc());
      if (remaining > _refreshThreshold) return _cachedToken!;
    }

    try {
      final stored     = await _storage.read(key: _tokenKey);
      final expiresStr = await _storage.read(key: _expiresKey);
      if (stored != null && expiresStr != null) {
        final expires = DateTime.tryParse(expiresStr)?.toUtc();
        if (expires != null) {
          final remaining = expires.difference(DateTime.now().toUtc());
          if (remaining > _refreshThreshold) {
            _cachedToken     = stored;
            _cachedExpiresAt = expires;
            return stored;
          }
        }
      }
    } catch (_) {}

    _inflightBootstrap ??= _bootstrap().whenComplete(() {
      _inflightBootstrap = null;
    });
    return _inflightBootstrap!;
  }

  Future<String> forceRefresh() async {
    _cachedToken     = null;
    _cachedExpiresAt = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiresKey);
    } catch (_) {}
    _inflightBootstrap = null;
    return getToken();
  }

  Future<String> _bootstrap() async {
    if (_tenantId.isEmpty) {
      throw const ApiException(0, 'PV_TENANT_ID not configured.', errorCode: 'TENANT_NOT_CONFIGURED');
    }

    final deviceId   = await _getOrCreateDeviceId();
    final platform   = Platform.isIOS ? 'ios' : 'android';
    final appVersion = Env.appVersion;

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/mobile/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'tenant_id':   _tenantId,
            'device_id':   deviceId,
            'platform':    platform,
            'app_version': appVersion,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body      = jsonDecode(response.body) as Map<String, dynamic>;
      final token     = body['token'] as String;
      final expiresAt = body['expires_at'] as String;
      final expires   = DateTime.parse(expiresAt).toUtc();

      try {
        await _storage.write(key: _tokenKey,   value: token);
        await _storage.write(key: _expiresKey, value: expiresAt);
      } catch (_) {}

      _cachedToken     = token;
      _cachedExpiresAt = expires;
      return token;
    }

    String errorCode = 'BOOTSTRAP_FAILED';
    try {
      final errBody = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = (errBody['error'] as Map<String, dynamic>?)?['code'] as String? ?? errorCode;
    } catch (_) {}
    throw ApiException(
      response.statusCode,
      'Mobile token bootstrap failed ($errorCode).',
      errorCode: errorCode,
    );
  }

  Future<String> _getOrCreateDeviceId() async {
    try {
      var id = await _storage.read(key: _deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await _storage.write(key: _deviceIdKey, value: id);
      }
      return id;
    } catch (_) {
      return const Uuid().v4();
    }
  }

  void dispose() => _client.close();
}
