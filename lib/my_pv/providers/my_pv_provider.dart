// My PV providers — customer asset wallet.
// Trust determination comes from the server exclusively.
// Unauthenticated callers receive empty lists / errors for upstream handling.

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

// ---------------------------------------------------------------------------
// Customer assets list
// GET /api/v1/customer/assets
// ---------------------------------------------------------------------------

final customerAssetsProvider = FutureProvider<List<CustomerAsset>>((ref) async {
  final session = ref.watch(currentUserProvider);
  if (session == null || session.isExpired) {
    throw Exception('not_authenticated');
  }

  final uri = Uri.parse('$_baseUrl/api/v1/customer/assets');
  final client = http.Client();
  try {
    final response = await client
        .get(uri, headers: _authHeaders(session.accessToken))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['assets'] as List? ?? []);
      return list
          .whereType<Map<String, dynamic>>()
          .map(CustomerAsset.fromJson)
          .toList();
    }
    if (response.statusCode == 401) throw Exception('not_authenticated');
    throw Exception('server_error:${response.statusCode}');
  } finally {
    client.close();
  }
});

// ---------------------------------------------------------------------------
// Asset detail
// GET /api/v1/customer/assets/:assetId
// Returns the full JSON map so the detail screen can access trust + evidence +
// custody history without this provider needing to know all field names upfront.
// ---------------------------------------------------------------------------

final assetDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, assetId) async {
  final session = ref.watch(currentUserProvider);
  if (session == null || session.isExpired) {
    throw Exception('not_authenticated');
  }

  final uri = Uri.parse(
      '$_baseUrl/api/v1/customer/assets/${Uri.encodeComponent(assetId)}');
  final client = http.Client();
  try {
    final response = await client
        .get(uri, headers: _authHeaders(session.accessToken))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw Exception('not_authenticated');
    if (response.statusCode == 404) throw Exception('not_found');
    throw Exception('server_error:${response.statusCode}');
  } finally {
    client.close();
  }
});
