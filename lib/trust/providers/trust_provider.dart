import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../trust_models.dart';
import '../../core/network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final trustRecordProvider =
    FutureProvider.family<TrustRecord, String>((ref, publicId) async {
  final client = ref.watch(apiClientProvider);
  final json = await client.trustLookup(publicId);
  return TrustRecord.fromJson(json);
});
