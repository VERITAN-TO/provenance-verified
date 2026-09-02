// Home providers — fetches alerts and submissions for authenticated customers.
// Graceful degradation: unauthenticated users get an empty list (no crash).
// NOTE: Trust tier values come from the server only.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/config/environment.dart';

// ---------------------------------------------------------------------------
// Shared Preferences — recent scans cache
// ---------------------------------------------------------------------------

const String _kRecentScansKey = 'pv_home_recent_scans';
const int _kMaxRecentScans = 5;

final recentScansProvider = FutureProvider<List<RecentScan>>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kRecentScansKey) ?? [];
    return raw
        .map((e) {
          try {
            return RecentScan.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentScan>()
        .toList();
  } catch (_) {
    return [];
  }
});

/// Saves a scan result to local cache.  Call this after a successful scan.
Future<void> saveRecentScan(RecentScan scan) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kRecentScansKey) ?? [];
    // Remove duplicate by publicId
    final filtered = existing.where((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m['public_id'] != scan.publicId;
      } catch (_) {
        return true;
      }
    }).toList();
    filtered.insert(0, jsonEncode(scan.toJson()));
    final trimmed = filtered.take(_kMaxRecentScans).toList();
    await prefs.setStringList(_kRecentScansKey, trimmed);
  } catch (_) {
    // Best-effort — never crash the app over cache write failures.
  }
}

// ---------------------------------------------------------------------------
// HTTP helper — customer-auth header
// ---------------------------------------------------------------------------

Map<String, String> _customerAuthHeaders(String accessToken) => {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

String get _baseUrl =>
    Env.pvApiBaseUrl.replaceAll(RegExp(r'/$'), '');

// ---------------------------------------------------------------------------
// Alerts provider
// ---------------------------------------------------------------------------

final homeAlertsProvider = FutureProvider<List<TrustAlert>>((ref) async {
  final session = ref.watch(currentUserProvider);
  if (session == null || session.isExpired) return [];

  final uri = Uri.parse('$_baseUrl/api/v1/customer/alerts');
  final client = http.Client();
  try {
    final response = await client
        .get(uri, headers: _customerAuthHeaders(session.accessToken))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['alerts'] as List? ?? []);
      return list
          .whereType<Map<String, dynamic>>()
          .map(TrustAlert.fromJson)
          .toList();
    }
    // Unauthenticated or server error — degrade gracefully.
    return [];
  } catch (_) {
    return [];
  } finally {
    client.close();
  }
});

// ---------------------------------------------------------------------------
// Submissions provider
// ---------------------------------------------------------------------------

final homeSubmissionsProvider = FutureProvider<List<SubmissionSummary>>((ref) async {
  final session = ref.watch(currentUserProvider);
  if (session == null || session.isExpired) return [];

  final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions');
  final client = http.Client();
  try {
    final response = await client
        .get(uri, headers: _customerAuthHeaders(session.accessToken))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['submissions'] as List? ?? []);
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubmissionSummary.fromJson)
          .toList();
    }
    return [];
  } catch (_) {
    return [];
  } finally {
    client.close();
  }
});
