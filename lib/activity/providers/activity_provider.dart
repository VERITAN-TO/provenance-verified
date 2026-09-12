// Activity providers — fetch submission list and detail from the backend.
// All data is server-authoritative. No fake data, no client-generated status.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/activity_models.dart';
import '../../core/config/environment.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submit/providers/submit_provider.dart' show SubmitApiException;

class _ActivityApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String? Function() _getToken;
  final Future<String?> Function() _refreshToken;

  _ActivityApiClient({
    http.Client? client,
    String? baseUrl,
    required String? Function() getToken,
    required Future<String?> Function() refreshToken,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _getToken = getToken,
        _refreshToken = refreshToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = await _refreshToken();
    if (token == null || token.isEmpty) throw Exception('Session refresh failed');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final nested = decoded['error'];
      if (nested is Map<String, dynamic>) {
        return {...decoded, 'message': nested['message']?.toString() ?? nested['code']?.toString()};
      }
      return decoded;
    } catch (_) {
      return {'message': res.reasonPhrase ?? 'Unknown error'};
    }
  }

  Future<List<SubmissionStatusItem>> listSubmissions() async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions');
    var res = await _client.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.get(uri, headers: await _refreshedHeaders()).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body);
      final list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['submissions'] as List<dynamic>? ?? [];
      return list.map((e) => SubmissionStatusItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Could not load submissions');
  }

  Future<SubmissionDetail> getSubmissionDetail(String submissionId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/${Uri.encodeComponent(submissionId)}/status');
    var res = await _client.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.get(uri, headers: await _refreshedHeaders()).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
      return SubmissionDetail.fromJson(data);
    }
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Could not load submission');
  }

  void dispose() => _client.close();
}

final _activityApiClientProvider = Provider<_ActivityApiClient>((ref) {
  final c = _ActivityApiClient(
    getToken: () => ref.read(authProvider)?.accessToken,
    refreshToken: () async {
      await ref.read(authProvider.notifier).refresh();
      return ref.read(authProvider)?.accessToken;
    },
  );
  ref.onDispose(c.dispose);
  return c;
});

final activityProvider = FutureProvider<List<SubmissionStatusItem>>((ref) async {
  final client = ref.watch(_activityApiClientProvider);
  final items = await client.listSubmissions();
  final sorted = List<SubmissionStatusItem>.from(items)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted;
});

final submissionDetailProvider = FutureProvider.family<SubmissionDetail, String>((ref, submissionId) async {
  final client = ref.watch(_activityApiClientProvider);
  return client.getSubmissionDetail(submissionId);
});
