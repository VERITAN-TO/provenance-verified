// Activity providers — fetch submission list and detail from the backend.
//
// All data is server-authoritative.  No fake data, no client-generated status.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/activity_models.dart';
import '../../core/config/environment.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submit/providers/submit_provider.dart' show submissionApiClientProvider, SubmitApiException;

// ---------------------------------------------------------------------------
// Activity API client — uses customer JWT, not M3 mobile token.
// ---------------------------------------------------------------------------

class _ActivityApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String? Function() _getToken;

  _ActivityApiClient({
    http.Client? client,
    String? baseUrl,
    required String? Function() getToken,
  })  : _client    = client ?? http.Client(),
        _baseUrl   = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _getToken  = getToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
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
  }
}

// ---------------------------------------------------------------------------
// Provider: shared activity API client
// ---------------------------------------------------------------------------

final _activityApiClientProvider = Provider<_ActivityApiClient>((ref) {
  final c = _ActivityApiClient(
    getToken: () => ref.read(authProvider)?.accessToken,
  );
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
