// M3: Mobile auth integration — dynamic token service, no static API key.
// Authentication: Bearer token issued by POST /api/v1/mobile/token (MobileTokenService).
// MTA2_CONTRACT: STATIC_PRODUCTION_API_KEY_IN_MOBILE = ZERO
//
// ENDPOINTS (all at pvApiBaseUrl / Vercel deployment):
//   GET  /api/v1/trust/{publicId}/machine  → MachineTrustResponse
//   POST /api/v1/actionability             → ActionabilityResponse
//   POST /api/v1/reliance-receipts         → RelianceReceipt
//
// trust_state_digest extracted from x-pv-trust-state-digest response header.
// physical_subject_id extracted from x-pv-physical-subject response header.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/mobile_token_service.dart';
import '../config/environment.dart';
import '../../trust/machine_trust_response.dart';

// Re-export ApiException so existing imports of api_client.dart still resolve it.
export '../auth/mobile_token_service.dart' show ApiException;

class ApiClient {
  final http.Client _client;
  final String _baseUrl;
  final MobileTokenService _tokenService;
  final bool _ownsTokenService;

  ApiClient({
    http.Client? client,
    String? baseUrl,
    MobileTokenService? tokenService,
  })  : _client           = client ?? http.Client(),
        _baseUrl          = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _ownsTokenService = tokenService == null,
        _tokenService     = tokenService ?? MobileTokenService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = await _tokenService.forceRefresh();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // GET /api/v1/trust/{publicId}/machine
  // Returns MachineTrustResponse with trust_state_digest from response header.
  Future<MachineTrustResponse> getMachineTrust(String publicId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/trust/${Uri.encodeComponent(publicId)}/machine');

    var response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      response = await _client
          .get(uri, headers: await _refreshedHeaders())
          .timeout(const Duration(seconds: 30));
    }

    final trustStateDigest = response.headers['x-pv-trust-state-digest'] ?? '';
    final physicalSubject  = response.headers['x-pv-physical-subject'] ?? '';

    if (response.statusCode == 200) {
      final json   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = MachineTrustResponse.fromJson(
        json,
        trustStateDigestHeader: trustStateDigest,
        physicalSubjectHeader:  physicalSubject,
      );
      if (result.hasError) {
        throw ApiException(response.statusCode, result.errorCode, errorCode: result.errorCode);
      }
      return result;
    }

    String errorCode = '';
    try {
      final errJson = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = (errJson['error'] as Map<String, dynamic>?)?['code'] as String? ?? '';
    } catch (_) {}
    throw ApiException(
      response.statusCode,
      response.reasonPhrase ?? 'Unknown',
      errorCode: errorCode.isNotEmpty ? errorCode : null,
    );
  }

  // POST /api/v1/actionability
  // Evaluates actionability for a given subject and purpose.
  Future<Map<String, dynamic>> evaluateActionability({
    required String subjectId,
    required String purposeId,
    required String requestedAction,
    required String claimScope,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/actionability');
    final body = jsonEncode({
      'subject_id':       subjectId,
      'purpose_id':       purposeId,
      'requested_action': requestedAction,
      'claim_scope':      claimScope,
    });

    var response = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      response = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String errorCode = '';
    try {
      final errJson = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = (errJson['error'] as Map<String, dynamic>?)?['code'] as String? ?? '';
    } catch (_) {}
    throw ApiException(
      response.statusCode,
      response.reasonPhrase ?? 'Unknown',
      errorCode: errorCode.isNotEmpty ? errorCode : null,
    );
  }

  // POST /api/v1/reliance-receipts
  // Creates a server-side reliance receipt. Requires reliance:create scope.
  Future<Map<String, dynamic>> createRelianceReceipt({
    required String subjectId,
    required String purposeId,
    required String requestedAction,
    required String claimScope,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/reliance-receipts');
    final body = jsonEncode({
      'subject_public_id': subjectId,
      'purpose_id':        purposeId,
      'requested_action':  requestedAction,
      'claim_scope':       claimScope,
    });

    var response = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      response = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String errorCode = '';
    try {
      final errJson = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = (errJson['error'] as Map<String, dynamic>?)?['code'] as String? ?? '';
    } catch (_) {}
    throw ApiException(
      response.statusCode,
      response.reasonPhrase ?? 'Unknown',
      errorCode: errorCode.isNotEmpty ? errorCode : null,
    );
  }

  void dispose() {
    _client.close();
    if (_ownsTokenService) _tokenService.dispose();
  }
}
