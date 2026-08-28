// M2: Real actionability provider.
// M1 Security Law: actionability must NEVER be cached for reliance — always fresh.
// PvConstants.actionabilityCacheForReliance = false enforces this at config level.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../actionability_models.dart';
import '../../trust/providers/trust_provider.dart';

// Parameters for actionability evaluation against the real backend.
typedef ActionabilityArgs = ({
  String publicId,
  String purposeId,
  String requestedAction,
  String claimScope,
  String principal,
  String organization,
});

// Evaluates actionability via POST /api/v1/actionability.
// NEVER cached for reliance — always fresh per M1 security law.
final actionabilityProvider = FutureProvider.family<ActionabilityResult, ActionabilityArgs>(
  (ref, args) async {
    final client = ref.watch(apiClientProvider);
    final json = await client.evaluateActionability(
      subjectId: args.publicId,
      purposeId: args.purposeId,
      requestedAction: args.requestedAction,
      claimScope: args.claimScope,
      principal: args.principal,
      organization: args.organization,
    );
    return ActionabilityResult.fromJson(json);
  },
);

// Compatibility: simple purpose-only actionability for UI callers.
final simpleActionabilityProvider = FutureProvider.family<ActionabilityResult, ({String publicId, String purpose})>(
  (ref, args) async {
    final client = ref.watch(apiClientProvider);
    final json = await client.evaluateActionability(
      subjectId: args.publicId,
      purposeId: args.purpose,
      requestedAction: 'evaluate',
      claimScope: 'standard',
      principal: 'mobile-consumer',
      organization: 'pv-mobile-qual',
    );
    return ActionabilityResult.fromJson(json);
  },
);
