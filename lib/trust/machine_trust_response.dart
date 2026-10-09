// M2: Real MachineTrustResponse — pv.machine-trust.v1 schema.
// Maps the REAL backend response to the TrustRecord model used by the UI.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52
//
// SERVER DETERMINES TRUST. MOBILE DISPLAYS TRUST.
// moneyControlsTrust = false: ALWAYS enforced regardless of server payload.
// UNQUALIFIED records: safeTier = null. Never render UNQUALIFIED as T1.

import 'trust_models.dart';

// ── Parsed types for pv.machine-trust.v1 ─────────────────────────────────────

class MtClaim {
  final String claimId;
  final String predicate;
  final String state;
  final List<String> supportingEvidence;
  final List<String> contradictingEvidence;

  const MtClaim({
    required this.claimId,
    required this.predicate,
    required this.state,
    this.supportingEvidence = const [],
    this.contradictingEvidence = const [],
  });

  factory MtClaim.fromJson(Map<String, dynamic> j) => MtClaim(
        claimId: j['claim_id'] as String? ?? '',
        predicate: j['predicate'] as String? ?? '',
        state: j['state'] as String? ?? 'UNKNOWN',
        supportingEvidence: (j['supporting_evidence'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        contradictingEvidence: (j['contradicting_evidence'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class MtLimitation {
  final String code;
  final String message;
  final String? affectedClaim;
  final List<String> prohibitedInferences;

  const MtLimitation({
    required this.code,
    required this.message,
    this.affectedClaim,
    this.prohibitedInferences = const [],
  });

  factory MtLimitation.fromJson(Map<String, dynamic> j) => MtLimitation(
        code: j['code'] as String? ?? '',
        message: j['message'] as String? ?? '',
        affectedClaim: j['affected_claim'] as String?,
        prohibitedInferences: (j['prohibited_inferences'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class MachineTrustResponse {
  final String schema;
  final String subjectId;
  final String subjectType;
  final String identityState;
  final List<MtClaim> claims;
  final String policyId;
  final String policyVersion;
  final String policyDigest;
  final String determinationId;
  final int tier;
  final String tierLabel;
  final bool current;
  final String determinationDigest;
  final bool eligible;
  final bool materialConflict;
  final List<MtLimitation> limitations;
  final List<String> prohibitedInferences;
  final String freshnessState;
  final String asOf;
  final String? validUntil;
  final String? requeueAfter;
  final bool determinationAuthoritative;
  final bool issuanceAuthorized;
  final String? authorityState;
  final bool? evidenceManifestValid;
  final bool? determinationDigestValid;
  final bool? credentialSignatureValid;
  final String? credentialId;
  final String credentialStatus;
  final bool credentialAuthoritative;
  final String continuityState;
  // current_custodian: who physically holds the asset (server-provided, display-only).
  // CUSTODY_IS_NOT_LEGAL_TITLE = TRUE — native must not assert legal title from this.
  final String? currentCustodian;
  // current_owner: server-reported legal title holder (display-only, no authority assertion).
  final String? currentOwner;
  final String lifecycleState;
  final String servedAt;
  // why_this_tier: server-authored list of requirements met for the current tier.
  final List<String> whyThisTier;
  // why_not_higher: server-authored list of gaps preventing the next tier.
  final List<String> whyNotHigher;
  // trust_state_digest comes from x-pv-trust-state-digest response header.
  final String trustStateDigest;
  // physical_subject_id comes from x-pv-physical-subject response header.
  final String physicalSubjectId;
  final Map<String, dynamic>? error;
  // Server-authored public verification URL — safe for Native sharing.
  // Constructed server-side from PV_SITE_URL env var; Native must NOT construct this from publicId.
  final String? publicRecordUrl;
  // Server-authored purchase qualification outcome. MONEY_CONTROLS_TRUST = FALSE.
  // QUALIFIED | UNQUALIFIED — from server purchase.qualification_outcome.
  final String? purchaseQualificationOutcome;

  const MachineTrustResponse({
    required this.schema,
    required this.subjectId,
    required this.subjectType,
    required this.identityState,
    required this.claims,
    required this.policyId,
    required this.policyVersion,
    required this.policyDigest,
    required this.determinationId,
    required this.tier,
    required this.tierLabel,
    required this.current,
    required this.determinationDigest,
    required this.eligible,
    required this.materialConflict,
    required this.limitations,
    required this.prohibitedInferences,
    required this.freshnessState,
    required this.asOf,
    this.validUntil,
    this.requeueAfter,
    required this.determinationAuthoritative,
    required this.issuanceAuthorized,
    this.authorityState,
    this.evidenceManifestValid,
    this.determinationDigestValid,
    this.credentialSignatureValid,
    this.credentialId,
    required this.credentialStatus,
    required this.credentialAuthoritative,
    required this.continuityState,
    this.currentCustodian,
    this.currentOwner,
    required this.lifecycleState,
    required this.servedAt,
    this.whyThisTier = const [],
    this.whyNotHigher = const [],
    required this.trustStateDigest,
    required this.physicalSubjectId,
    this.error,
    this.publicRecordUrl,
    this.purchaseQualificationOutcome,
  });

  bool get hasError => error != null;
  String get errorCode => error?['code'] as String? ?? '';

  factory MachineTrustResponse.fromJson(
    Map<String, dynamic> j, {
    required String trustStateDigestHeader,
    required String physicalSubjectHeader,
  }) {
    final subject = j['subject'] as Map<String, dynamic>? ?? {};
    final policy = j['policy'] as Map<String, dynamic>? ?? {};
    final determination = j['determination'] as Map<String, dynamic>? ?? {};
    final freshness = j['freshness'] as Map<String, dynamic>? ?? {};
    final authority = j['authority'] as Map<String, dynamic>? ?? {};
    final integrity = j['integrity'] as Map<String, dynamic>? ?? {};
    final credential = j['credential'] as Map<String, dynamic>? ?? {};
    final continuity = j['continuity'] as Map<String, dynamic>? ?? {};
    final lifecycle = j['lifecycle'] as Map<String, dynamic>? ?? {};
    final purchase = j['purchase'] as Map<String, dynamic>? ?? {};

    return MachineTrustResponse(
      schema: j['schema'] as String? ?? 'pv.machine-trust.v1',
      subjectId: subject['subject_id'] as String? ?? '',
      subjectType: subject['subject_type'] as String? ?? '',
      identityState: subject['identity_state'] as String? ?? 'UNKNOWN',
      claims: (j['claims'] as List?)
              ?.map((c) => MtClaim.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      policyId: policy['policy_id'] as String? ?? '',
      policyVersion: policy['policy_version'] as String? ?? '',
      policyDigest: policy['policy_digest'] as String? ?? '',
      determinationId: determination['determination_id'] as String? ?? '',
      tier: (determination['tier'] as num?)?.toInt() ?? 0,
      tierLabel: determination['tier_label'] as String? ?? '',
      current: determination['current'] as bool? ?? false,
      determinationDigest: determination['determination_digest'] as String? ?? '',
      eligible: determination['eligible'] as bool? ?? false,
      materialConflict: determination['material_conflict'] as bool? ?? false,
      limitations: (j['limitations'] as List?)
              ?.map((l) => MtLimitation.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      prohibitedInferences: (j['prohibited_inferences'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      freshnessState: freshness['state'] as String? ?? 'UNKNOWN',
      asOf: freshness['as_of'] as String? ?? j['as_of'] as String? ?? '',
      validUntil: freshness['valid_until'] as String?,
      requeueAfter: freshness['requery_after'] as String?,
      determinationAuthoritative: authority['determination_authoritative'] as bool? ?? false,
      issuanceAuthorized: authority['issuance_authorized'] as bool? ?? false,
      authorityState: authority['authority_state'] as String?,
      evidenceManifestValid: integrity['evidence_manifest_valid'] as bool?,
      determinationDigestValid: integrity['determination_digest_valid'] as bool?,
      credentialSignatureValid: integrity['credential_signature_valid'] as bool?,
      credentialId: credential['credential_id'] as String?,
      credentialStatus: credential['status'] as String? ?? 'UNKNOWN',
      credentialAuthoritative: credential['authoritative'] as bool? ?? false,
      continuityState: continuity['state'] as String? ?? 'UNKNOWN',
      currentCustodian: continuity['current_custodian'] as String?,
      currentOwner: continuity['current_owner'] as String?,
      lifecycleState: lifecycle['state'] as String? ?? 'UNKNOWN',
      whyThisTier: (determination['why_this_tier'] as List?)
              ?.map((e) {
                final entry = e as Map<String, dynamic>? ?? {};
                return (entry['requirement'] as String?) ??
                    (entry['reason_code'] as String?) ??
                    '';
              })
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      whyNotHigher: (determination['why_not_higher'] as List?)
              ?.map((e) {
                final entry = e as Map<String, dynamic>? ?? {};
                return (entry['missing_requirement'] as String?) ??
                    (entry['reason_code'] as String?) ??
                    '';
              })
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      servedAt: j['served_at'] as String? ?? '',
      trustStateDigest: trustStateDigestHeader.isNotEmpty
          ? trustStateDigestHeader
          : determination['determination_digest'] as String? ?? '',
      physicalSubjectId: physicalSubjectHeader.isNotEmpty
          ? physicalSubjectHeader
          : subject['subject_id'] as String? ?? '',
      error: j['error'] as Map<String, dynamic>?,
      publicRecordUrl: j['public_record_url'] as String?,
      purchaseQualificationOutcome: purchase['qualification_outcome'] as String?,
    );
  }

  // Map to TrustRecord for the UI layer.
  // SECURITY LAWS (preserved from M1):
  //   moneyControlsTrust = false: ALWAYS. Never trust server payload for this.
  //   UNQUALIFIED records: safeTier = null.
  TrustRecord toTrustRecord(String publicId) {
    // Map identity state
    final identState = IdentityState.fromJson(identityState);

    // Map continuity state
    final contState = ContinuityState.fromJson(continuityState);

    // Map claims to ClaimVerdict
    final claimVerdicts = claims.map((c) => ClaimVerdict(
      claimId: c.claimId,
      predicate: c.predicate,
      assertedValue: '',
      claimState: ClaimState.fromJson(c.state),
      material: false,
    )).toList();

    // Map limitations — prohibitedInferences from server's per-limitation field, not affectedClaim.
    final lims = limitations.map((l) => TrustLimitation(
      code: l.code,
      message: l.message,
      prohibitedInferences: l.prohibitedInferences,
    )).toList();

    // Map freshness
    TrustFreshness? freshness;
    if (asOf.isNotEmpty) {
      freshness = TrustFreshness(
        state: FreshnessState.fromJson(freshnessState),
        lastVerified: DateTime.tryParse(asOf),
        nextVerifyBy: validUntil != null ? DateTime.tryParse(validUntil!) : null,
      );
    }

    // Map determination — metRequirements/notMetRequirements from server's why_this_tier/why_not_higher.
    final determination = TrustDetermination(
      determinationId: determinationId,
      tier: tier,
      eligible: eligible,
      qualificationState: eligible ? QualificationState.qualified : QualificationState.unqualified,
      materialConflict: materialConflict,
      tierRationale: tierLabel.isNotEmpty ? tierLabel : null,
      metRequirements: whyThisTier,
      notMetRequirements: whyNotHigher,
      purchaseQualificationOutcome: purchaseQualificationOutcome,
    );

    // Map authority
    final authority = TrustAuthority(
      credentialId: credentialId,
      credentialValid: credentialAuthoritative,
    );

    // Map lifecycle
    final lifecycle = TrustLifecycle(
      status: lifecycleState,
    );

    // Map continuity — currentCustodian/currentOwner from server (display-only, CUSTODY_IS_NOT_LEGAL_TITLE=TRUE).
    TrustContinuity? continuity;
    if (contState != ContinuityState.unknown || currentCustodian != null || currentOwner != null) {
      continuity = TrustContinuity(
        state: contState,
        currentCustodian: currentCustodian,
        currentOwner: currentOwner,
      );
    }

    return TrustRecord(
      publicId: publicId,
      trustStateDigest: trustStateDigest,
      publicRecordUrl: publicRecordUrl,
      subject: TrustSubject(
        subjectId: subjectId,
        physicalSubjectId: physicalSubjectId,
        identityState: identState,
        continuityState: contState,
      ),
      claimVerdicts: claimVerdicts,
      evidence: const [],
      determination: determination,
      continuity: continuity,
      freshness: freshness,
      authority: authority,
      lifecycle: lifecycle,
      limitations: lims,
      prohibitedInferences: prohibitedInferences,
      moneyControlsTrust: false, // ALWAYS false — MTA1 security law
    );
  }
}
