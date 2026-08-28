import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> trustLookup(String publicId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/pv-trust-lookup');
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (Env.supabaseAnonKey.isNotEmpty)
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
          },
          body: jsonEncode({'public_id': publicId}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.reasonPhrase ?? 'Unknown');
  }

  Future<Map<String, dynamic>> actionabilityCheck({
    required String publicId,
    required String purpose,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/pv-actionability');
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (Env.supabaseAnonKey.isNotEmpty)
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
          },
          body: jsonEncode({'public_id': publicId, 'purpose': purpose}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.reasonPhrase ?? 'Unknown');
  }

  void dispose() => _client.close();
}
