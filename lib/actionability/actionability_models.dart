// M2: Actionability contract — real pv.machine-actionability.v1 schema.
// UNKNOWN must NOT be treated as soft ALLOW. Fail-closed.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

enum ActionabilityDecision {
  allow,
  qualify,
  deny,
  unknown;

  String get displayLabel {
    switch (this) {
      case allow: return 'ALLOW';
      case qualify: return 'ALLOW WITH QUALIFICATIONS';
      case deny: return 'DENY';
      case unknown: return 'UNKNOWN';
    }
  }

  // FAIL CLOSED: any unrecognized value maps to UNKNOWN (not ALLOW).
  static ActionabilityDecision fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString().toUpperCase()) {
      case 'ALLOW': return allow;
      case 'QUALIFY': return qualify;
      case 'DENY': return deny;
      default: return unknown;
    }
  }
}

enum ActionabilityPurpose {
  purchase,
  publicMarketingClaim,
  insurance,
  resale,
  custom;

  String get displayLabel {
    switch (this) {
      case purchase: return 'Purchase';
      case publicMarketingClaim: return 'Public Marketing Claim';
      case insurance: return 'Insurance';
      case resale: return 'Resale';
      case custom: return 'Custom';
    }
  }

  String toJson() {
    switch (this) {
      case publicMarketingClaim: return 'PUBLIC_MARKETING_CLAIM';
      default: return name.toUpperCase();
    }
  }

  static ActionabilityPurpose fromJson(dynamic v) {
    if (v == null) return custom;
    switch (v.toString().toUpperCase()) {
      case 'PURCHASE': return purchase;
      case 'PUBLIC_MARKETING_CLAIM': return publicMarketingClaim;
      case 'INSURANCE': return insurance;
      case 'RESALE': return resale;
      default: return custom;
    }
  }
}

// Maps pv.machine-actionability.v1 response.
class ActionabilityResult {
  final ActionabilityDecision decision;
  final String schema;
  final List<String> reasonCodes;
  final String? rationale;
  final List<String> qualifications;
  final List<String> limitations;
  final List<String> prohibitedInferences;
  final String? policyVersion;
  // trust_state_digest from the actionability response — for reliance receipt.
  final String trustStateDigest;
  final String? receiptId;
  final String asOf;

  const ActionabilityResult({
    required this.decision,
    this.schema = 'pv.machine-actionability.v1',
    this.reasonCodes = const [],
    this.rationale,
    this.qualifications = const [],
    this.limitations = const [],
    this.prohibitedInferences = const [],
    this.policyVersion,
    this.trustStateDigest = '',
    this.receiptId,
    this.asOf = '',
  });

  factory ActionabilityResult.fromJson(Map<String, dynamic> j) => ActionabilityResult(
        decision: ActionabilityDecision.fromJson(j['decision']),
        schema: j['schema'] as String? ?? 'pv.machine-actionability.v1',
        reasonCodes: (j['reason_codes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        rationale: j['rationale'] as String?,
        qualifications: (j['qualifications'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        limitations: (j['limitations'] as List?)?.map((e) => e.toString()).toList() ?? [],
        prohibitedInferences: (j['prohibited_inferences'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        policyVersion: j['policy_version'] as String?,
        trustStateDigest: j['trust_state_digest'] as String? ?? '',
        receiptId: j['receipt_id'] as String?,
        asOf: j['as_of'] as String? ?? '',
      );
}
