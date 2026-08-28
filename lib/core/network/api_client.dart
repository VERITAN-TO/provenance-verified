// M2: Real API client — calls REAL PV backend endpoints.
// Authentication: Authorization: Bearer <PV_API_KEY>
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52
//
// ENDPOINTS (all at pvApiBaseUrl / Vercel deployment):
//   GET  /api/v1/trust/{publicId}/machine  → MachineTrustResponse
//   POST /api/v1/actionability             → ActionabilityResponse
//
// trust_state_digest extracted from x-pv-trust-state-digest response header.
// physical_subject_id extracted from x-pv-physical-subject response header.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../../trust/machine_trust_response.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;
  const ApiException(this.statusCode, this.message, {this.errorCode});
  @override
  String toString() => 'ApiException($statusCode/${errorCode ?? ''}): $message';
}

class ApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  ApiClient({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _apiKey = apiKey ?? Env.pvApiKey;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      };

  // GET /api/v1/trust/{publicId}/machine
  // Returns MachineTrustResponse with trust_state_digest from response header.
  Future<MachineTrustResponse> getMachineTrust(String publicId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/trust/${Uri.encodeComponent(publicId)}/machine');
    final response = await _client
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));

    final trustStateDigest = response.headers['x-pv-trust-state-digest'] ?? '';
    final physicalSubject = response.headers['x-pv-physical-subject'] ?? '';

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = MachineTrustResponse.fromJson(
        json,
        trustStateDigestHeader: trustStateDigest,
        physicalSubjectHeader: physicalSubject,
      );
      if (result.hasError) {
        throw ApiException(response.statusCode, result.errorCode, errorCode: result.errorCode);
      }
      return result;
    }

    // Parse error body if possible
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
    required String principal,
    required String organization,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/actionability');
    final response = await _client
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'subject_id': subjectId,
            'purpose_id': purposeId,
            'requested_action': requestedAction,
            'claim_scope': claimScope,
            'principal': principal,
            'organization': organization,
          }),
        )
        .timeout(const Duration(seconds: 30));

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
    final uri = Uri.parse('$_baseUrl/api/v1/reliance-receipts');
    final response = await _client
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'subject_id': subjectId,
            'purpose_id': purposeId,
            'requested_action': requestedAction,
            'claim_scope': claimScope,
          }),
        )
        .timeout(const Duration(seconds: 30));

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

  void dispose() => _client.close();
}
