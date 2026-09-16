// My PV providers — customer asset wallet.
// Trust determination comes from the server exclusively.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/my_pv_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/config/environment.dart';

String get _baseUrl => Env.pvApiBaseUrl.replaceAll(RegExp(r'/$'), '');
Map<String, String> _authHeaders(String accessToken) => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $accessToken',
};

Future<String> _validToken(Ref ref) async {
  CustomerSession? session = ref.read(currentUserProvider);
  if (session == null) throw Exception('not_authenticated');
  if (session.isExpired) {
    await ref.read(authProvider.notifier).refresh();
    session = ref.read(currentUserProvider);
  }
  if (session == null || session.accessToken.isEmpty || session.isExpired) {
    throw Exception('not_authenticated');
  }
  return session.accessToken;
}

Future<http.Response> _getWithOneRefresh(Ref ref, Uri uri, http.Client client) async {
  var token = await _validToken(ref);
  var response = await client.get(uri, headers: _authHeaders(token)).timeout(const Duration(seconds: 30));
  if (response.statusCode == 401) {
    await ref.read(authProvider.notifier).refresh();
    token = await _validToken(ref);
    response = await client.get(uri, headers: _authHeaders(token)).timeout(const Duration(seconds: 30));
  }
  return response;
}

final customerAssetsProvider = FutureProvider<List<CustomerAsset>>((ref) async {
  final uri = Uri.parse('$_baseUrl/api/v1/customer/assets');
  final client = http.Client();
  try {
    final response = await _getWithOneRefresh(ref, uri, client);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['assets'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(CustomerAsset.fromJson).toList();
    }
    if (response.statusCode == 401) throw Exception('not_authenticated');
    throw Exception('server_error:${response.statusCode}');
  } finally {
    client.close();
  }
});

final assetDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, assetId) async {
  final uri = Uri.parse('$_baseUrl/api/v1/customer/assets/${Uri.encodeComponent(assetId)}');
  final client = http.Client();
  try {
    final response = await _getWithOneRefresh(ref, uri, client);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is Map<String, dynamic> && data['asset'] is Map<String, dynamic>) {
        return data['asset'] as Map<String, dynamic>;
      }
      return body;
    }
    if (response.statusCode == 401) throw Exception('not_authenticated');
    if (response.statusCode == 404) throw Exception('not_found');
    throw Exception('server_error:${response.statusCode}');
  } finally {
    client.close();
  }
});
