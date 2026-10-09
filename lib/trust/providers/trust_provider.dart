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
// R45: autoDispose — a non-autoDispose family can serve a previously-fetched trust
// record to a new Verify session without a fresh server call, silently presenting
// stale lifecycle/revocation state as current authority. autoDispose disposes state
// when all listeners are removed. Nested same-route consumers (TrustResultScreen +
// WhyThisTier + WhyNotHigher + Authority) remain alive together; the provider only
// disposes when the user fully leaves the verify flow — exactly the intended scope.
final trustRecordProvider =
    FutureProvider.autoDispose.family<TrustRecord, String>((ref, publicId) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.getMachineTrust(publicId);
  return response.toTrustRecord(publicId);
});
