import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../actionability_models.dart';
import '../../trust/providers/trust_provider.dart';

// M1 Security Law: actionability must NEVER be cached for reliance — always fresh.
// PvConstants.actionabilityCacheForReliance = false enforces this at config level.
final actionabilityProvider = FutureProvider.family<ActionabilityResult, ({String publicId, String purpose})>(
  (ref, args) async {
    final client = ref.watch(apiClientProvider);
    final json = await client.actionabilityCheck(
      publicId: args.publicId,
      purpose: args.purpose,
    );
    return ActionabilityResult.fromJson(json);
  },
);
