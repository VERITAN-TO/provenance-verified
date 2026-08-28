// M2: Real trust provider — calls real backend via getMachineTrust().
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../trust_models.dart';
import '../../core/network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

// Fetches real MachineTrustResponse and maps to TrustRecord for the UI.
// trust_state_digest comes from x-pv-trust-state-digest response header.
final trustRecordProvider =
    FutureProvider.family<TrustRecord, String>((ref, publicId) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.getMachineTrust(publicId);
  return response.toTrustRecord(publicId);
});
