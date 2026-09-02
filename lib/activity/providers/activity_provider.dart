// Activity providers — fetch submission list and detail from the backend.
//
// All data is server-authoritative.  No fake data, no client-generated status.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/activity_models.dart';
import '../../core/config/environment.dart';
import '../../core/auth/mobile_token_service.dart';
import '../../submit/providers/submit_provider.dart' show submissionApiClientProvider, SubmitApiException;

// ---------------------------------------------------------------------------
// Activity API client (thin wrapper; reuses SubmissionApiClient's token layer)
// ---------------------------------------------------------------------------

class _ActivityApiClient {
  final http.Client _client;
  final String _baseUrl;
  final MobileTokenService _tokenService;
  final bool _ownsTokenService;

  _ActivityApiClient({
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

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'message': res.reasonPhrase ?? 'Unknown error'};
    }
  }

  // GET /api/v1/customer/submissions
  Future<List<SubmissionStatusItem>> listSubmissions() async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions');

    var res = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .get(uri, headers: await _refreshedHeaders())
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body);
      final list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['submissions'] as List<dynamic>? ?? [];
      return list
          .map((e) => SubmissionStatusItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final err = _parseError(res);
    throw SubmitApiException(
        res.statusCode, err['message'] as String? ?? 'Could not load submissions');
  }

  // GET /api/v1/customer/submissions/:id/status
  Future<SubmissionDetail> getSubmissionDetail(String submissionId) async {
    final uri = Uri.parse(
        '$_baseUrl/api/v1/customer/submissions/${Uri.encodeComponent(submissionId)}/status');

    var res = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .get(uri, headers: await _refreshedHeaders())
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200) {
      return SubmissionDetail.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }

    final err = _parseError(res);
    throw SubmitApiException(
        res.statusCode, err['message'] as String? ?? 'Could not load submission');
  }

  void dispose() {
    _client.close();
    if (_ownsTokenService) _tokenService.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider: shared activity API client
// ---------------------------------------------------------------------------

final _activityApiClientProvider = Provider<_ActivityApiClient>((ref) {
  final c = _ActivityApiClient();
  ref.onDispose(c.dispose);
  return c;
});

// ---------------------------------------------------------------------------
// activityProvider — list of submissions, newest first
// ---------------------------------------------------------------------------

final activityProvider =
    FutureProvider<List<SubmissionStatusItem>>((ref) async {
  final client = ref.watch(_activityApiClientProvider);
  final items  = await client.listSubmissions();
  // Sort newest-first by updatedAt
  final sorted = List<SubmissionStatusItem>.from(items)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted;
});

// ---------------------------------------------------------------------------
// submissionDetailProvider — detail for a single submission
// ---------------------------------------------------------------------------

final submissionDetailProvider =
    FutureProvider.family<SubmissionDetail, String>((ref, submissionId) async {
  final client = ref.watch(_activityApiClientProvider);
  return client.getSubmissionDetail(submissionId);
});
