// MTA-1 Trust Models — DO NOT add local trust determination logic.
// SERVER DETERMINES TRUST. MOBILE DISPLAYS TRUST.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

// NOTE: This file is written for use WITHOUT code generation (no build_runner needed).
// All models are implemented as plain Dart classes with manual fromJson/toJson.
// This ensures tests can run immediately without a code generation step.

enum IdentityState {
  resolved,
  ambiguous,
  unresolved,
  unknown;

  static IdentityState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'RESOLVED': return resolved;
      case 'AMBIGUOUS': return ambiguous;
      case 'UNRESOLVED': return unresolved;
      default: return unknown;
    }
  }

  String toJson() => name.toUpperCase();
}

enum ClaimState {
  supported,
  asserted,
  contradicted,
  revoked,
  insufficient,
  unknown;

  bool get isPositive => this == supported;
  bool get isNegative => this == contradicted || this == revoked;

  static ClaimState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'SUPPORTED': return supported;
      case 'ASSERTED': return asserted;
      case 'CONTRADICTED': return contradicted;
      case 'REVOKED': return revoked;
      case 'INSUFFICIENT': return insufficient;
      default: return unknown;
    }
  }

  String toJson() => name.toUpperCase();
}

enum FreshnessState {
  current,
  approachingStale,
  stale,
  expired,
  reverifyRequired,
  unknown;

  bool get requiresRequery =>
      this == stale || this == expired || this == reverifyRequired;

  static FreshnessState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'CURRENT': return current;
      case 'APPROACHING_STALE': return approachingStale;
      case 'STALE': return stale;
      case 'EXPIRED': return expired;
      case 'REVERIFY_REQUIRED': return reverifyRequired;
      default: return unknown;
    }
  }

  String toJson() {
    switch (this) {
      case approachingStale: return 'APPROACHING_STALE';
      case reverifyRequired: return 'REVERIFY_REQUIRED';
      default: return name.toUpperCase();
    }
  }
}

enum ContinuityState {
  known,
  partial,
  gap,
  conflict,
  unknown;

  bool get hasMaterialLimitation => this == gap || this == conflict;

  static ContinuityState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'KNOWN': return known;
      case 'PARTIAL': return partial;
      case 'GAP': return gap;
      case 'CONFLICT': return conflict;
      default: return unknown;
    }
  }

  String toJson() => name.toUpperCase();
}

enum SubjectMatchState {
  confirmedMatch,
  probableMatch,
  insufficientMatch,
  noMatch,
  conflictingMatch,
  unknown;

  bool get canContributeToVerification =>
      this == confirmedMatch || this == probableMatch;

  static SubjectMatchState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'CONFIRMED_MATCH': return confirmedMatch;
      case 'PROBABLE_MATCH': return probableMatch;
      case 'INSUFFICIENT_MATCH': return insufficientMatch;
      case 'NO_MATCH': return noMatch;
      case 'CONFLICTING_MATCH': return conflictingMatch;
      default: return unknown;
    }
  }

  String toJson() {
    switch (this) {
      case confirmedMatch: return 'CONFIRMED_MATCH';
      case probableMatch: return 'PROBABLE_MATCH';
      case insufficientMatch: return 'INSUFFICIENT_MATCH';
      case noMatch: return 'NO_MATCH';
      case conflictingMatch: return 'CONFLICTING_MATCH';
      default: return 'UNKNOWN';
    }
  }
}

enum RelatedPartyState {
  relatedParty,
  independent,
  unknownState,
  notRecorded;

  bool get isRelated => this == relatedParty;

  static RelatedPartyState fromJson(dynamic v) {
    if (v == null) return notRecorded;
    if (v is bool) return v ? relatedParty : independent;
    switch (v.toString()) {
      case 'true': return relatedParty;
      case 'false': return independent;
      case 'UNKNOWN': return unknownState;
      case 'NOT_RECORDED': return notRecorded;
      default: return unknownState;
    }
  }

  dynamic toJson() {
    switch (this) {
      case relatedParty: return true;
      case independent: return false;
      case unknownState: return 'UNKNOWN';
      case notRecorded: return 'NOT_RECORDED';
    }
  }
}

enum QualificationState {
  qualified,
  unqualified,
  pending,
  unknown;

  static QualificationState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'QUALIFIED': return qualified;
      case 'UNQUALIFIED': return unqualified;
      case 'PENDING': return pending;
      default: return unknown;
    }
  }

  String toJson() => name.toUpperCase();
}

enum IntegrityVerificationState {
  verified,
  presentUnverified,
  failed,
  notApplicable,
  unknown;

  static IntegrityVerificationState fromJson(dynamic v) {
    if (v == null) return unknown;
    switch (v.toString()) {
      case 'VERIFIED': return verified;
      case 'PRESENT_UNVERIFIED': return presentUnverified;
      case 'FAILED': return failed;
      case 'NOT_APPLICABLE': return notApplicable;
      default: return unknown;
    }
  }

  String toJson() {
    switch (this) {
      case presentUnverified: return 'PRESENT_UNVERIFIED';
      case notApplicable: return 'NOT_APPLICABLE';
      default: return name.toUpperCase();
    }
  }
}

class TrustSubject {
  final String subjectId;
  final String physicalSubjectId;
  final IdentityState identityState;
  final ContinuityState continuityState;
  final SubjectMatchState? subjectMatchState;

  const TrustSubject({
    required this.subjectId,
    required this.physicalSubjectId,
    this.identityState = IdentityState.unknown,
    this.continuityState = ContinuityState.unknown,
    this.subjectMatchState,
  });

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'physical_subject_id': physicalSubjectId,
        'identity_state': identityState.toJson(),
        'continuity_state': continuityState.toJson(),
        if (subjectMatchState != null) 'subject_match_state': subjectMatchState!.toJson(),
      };

  factory TrustSubject.fromJson(Map<String, dynamic> j) => TrustSubject(
        subjectId: j['subject_id'] as String? ?? '',
        physicalSubjectId: j['physical_subject_id'] as String? ?? '',
        identityState: IdentityState.fromJson(j['identity_state']),
        continuityState: ContinuityState.fromJson(j['continuity_state']),
        subjectMatchState: j['subject_match_state'] != null
            ? SubjectMatchState.fromJson(j['subject_match_state'])
            : null,
      );
}

class ClaimVerdict {
  final String claimId;
  final String predicate;
  final String assertedValue;
  final ClaimState claimState;
  final bool material;
  final RelatedPartyState? sourceRelatedParty;

  const ClaimVerdict({
    required this.claimId,
    required this.predicate,
    required this.assertedValue,
    required this.claimState,
    this.material = false,
    this.sourceRelatedParty,
  });

  Map<String, dynamic> toJson() => {
        'claim_id': claimId,
        'predicate': predicate,
        'asserted_value': assertedValue,
        'claim_state': claimState.toJson(),
        'material': material,
        if (sourceRelatedParty != null) 'source_related_party': sourceRelatedParty!.toJson(),
      };

  factory ClaimVerdict.fromJson(Map<String, dynamic> j) => ClaimVerdict(
        claimId: j['claim_id'] as String? ?? '',
        predicate: j['predicate'] as String? ?? '',
        assertedValue: j['asserted_value'] as String? ?? '',
        claimState: ClaimState.fromJson(j['claim_state']),
        material: j['material'] as bool? ?? false,
        sourceRelatedParty: j['source_related_party'] != null
            ? RelatedPartyState.fromJson(j['source_related_party'])
            : null,
      );
}

class EvidenceItem {
  final String evidenceId;
  final String type;
  final String source;
  final IntegrityVerificationState integrityVerificationState;
  final SubjectMatchState subjectMatchState;
  final RelatedPartyState relatedParty;

  const EvidenceItem({
    required this.evidenceId,
    required this.type,
    required this.source,
    this.integrityVerificationState = IntegrityVerificationState.unknown,
    this.subjectMatchState = SubjectMatchState.unknown,
    this.relatedParty = RelatedPartyState.notRecorded,
  });

  Map<String, dynamic> toJson() => {
        'evidence_id': evidenceId,
        'type': type,
        'source': source,
        'integrity_verification_state': integrityVerificationState.toJson(),
        'subject_match_state': subjectMatchState.toJson(),
        'related_party': relatedParty.toJson(),
      };

  factory EvidenceItem.fromJson(Map<String, dynamic> j) => EvidenceItem(
        evidenceId: j['evidence_id'] as String? ?? '',
        type: j['type'] as String? ?? '',
        source: j['source'] as String? ?? '',
        integrityVerificationState:
            IntegrityVerificationState.fromJson(j['integrity_verification_state']),
        subjectMatchState: SubjectMatchState.fromJson(j['subject_match_state']),
        relatedParty: RelatedPartyState.fromJson(j['related_party']),
      );
}

class TrustDetermination {
  final String determinationId;
  final int tier;
  final bool eligible;
  final QualificationState qualificationState;
  final bool materialConflict;
  final String? tierRationale;
  final List<String> metRequirements;
  final List<String> notMetRequirements;

  const TrustDetermination({
    required this.determinationId,
    required this.tier,
    required this.eligible,
    this.qualificationState = QualificationState.unknown,
    this.materialConflict = false,
    this.tierRationale,
    this.metRequirements = const [],
    this.notMetRequirements = const [],
  });

  Map<String, dynamic> toJson() => {
        'determination_id': determinationId,
        'tier': tier,
        'eligible': eligible,
        'qualification_state': qualificationState.toJson(),
        'material_conflict': materialConflict,
        if (tierRationale != null) 'tier_rationale': tierRationale,
        'met_requirements': metRequirements,
        'not_met_requirements': notMetRequirements,
      };

  factory TrustDetermination.fromJson(Map<String, dynamic> j) => TrustDetermination(
        determinationId: j['determination_id'] as String? ?? '',
        tier: j['tier'] as int? ?? 0,
        eligible: j['eligible'] as bool? ?? false,
        qualificationState: QualificationState.fromJson(j['qualification_state']),
        materialConflict: j['material_conflict'] as bool? ?? false,
        tierRationale: j['tier_rationale'] as String?,
        metRequirements: (j['met_requirements'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        notMetRequirements: (j['not_met_requirements'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class TrustLimitation {
  final String code;
  final String message;
  final List<String> prohibitedInferences;

  const TrustLimitation({
    required this.code,
    required this.message,
    this.prohibitedInferences = const [],
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'prohibited_inferences': prohibitedInferences,
      };

  factory TrustLimitation.fromJson(Map<String, dynamic> j) => TrustLimitation(
        code: j['code'] as String? ?? '',
        message: j['message'] as String? ?? '',
        prohibitedInferences: (j['prohibited_inferences'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class TrustContinuity {
  final ContinuityState state;
  final String? gapDescription;

  const TrustContinuity({
    required this.state,
    this.gapDescription,
  });

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        if (gapDescription != null) 'gap_description': gapDescription,
      };

  factory TrustContinuity.fromJson(Map<String, dynamic> j) => TrustContinuity(
        state: ContinuityState.fromJson(j['state']),
        gapDescription: j['gap_description'] as String?,
      );
}

class TrustFreshness {
  final FreshnessState state;
  final DateTime? lastVerified;
  final DateTime? nextVerifyBy;

  const TrustFreshness({
    required this.state,
    this.lastVerified,
    this.nextVerifyBy,
  });

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        if (lastVerified != null) 'last_verified': lastVerified!.toIso8601String(),
        if (nextVerifyBy != null) 'next_verify_by': nextVerifyBy!.toIso8601String(),
      };

  factory TrustFreshness.fromJson(Map<String, dynamic> j) => TrustFreshness(
        state: FreshnessState.fromJson(j['state']),
        lastVerified: j['last_verified'] != null
            ? DateTime.tryParse(j['last_verified'] as String)
            : null,
        nextVerifyBy: j['next_verify_by'] != null
            ? DateTime.tryParse(j['next_verify_by'] as String)
            : null,
      );
}

class TrustAuthority {
  final String? issuingEntity;
  final String? credentialId;
  final bool? credentialValid;

  const TrustAuthority({
    this.issuingEntity,
    this.credentialId,
    this.credentialValid,
  });

  Map<String, dynamic> toJson() => {
        if (issuingEntity != null) 'issuing_entity': issuingEntity,
        if (credentialId != null) 'credential_id': credentialId,
        if (credentialValid != null) 'credential_valid': credentialValid,
      };

  factory TrustAuthority.fromJson(Map<String, dynamic> j) => TrustAuthority(
        issuingEntity: j['issuing_entity'] as String?,
        credentialId: j['credential_id'] as String?,
        credentialValid: j['credential_valid'] as bool?,
      );
}

class TrustLifecycle {
  final String? status;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? supersededBy;

  const TrustLifecycle({
    this.status,
    this.issuedAt,
    this.expiresAt,
    this.supersededBy,
  });

  Map<String, dynamic> toJson() => {
        if (status != null) 'status': status,
        if (issuedAt != null) 'issued_at': issuedAt!.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (supersededBy != null) 'superseded_by': supersededBy,
      };

  factory TrustLifecycle.fromJson(Map<String, dynamic> j) => TrustLifecycle(
        status: j['status'] as String?,
        issuedAt: j['issued_at'] != null ? DateTime.tryParse(j['issued_at'] as String) : null,
        expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at'] as String) : null,
        supersededBy: j['superseded_by'] as String?,
      );
}

class TrustRecord {
  final String publicId;
  final String trustStateDigest;
  final TrustSubject subject;
  final List<ClaimVerdict> claimVerdicts;
  final List<EvidenceItem> evidence;
  final TrustDetermination? determination;
  final TrustContinuity? continuity;
  final TrustFreshness? freshness;
  final TrustAuthority? authority;
  final TrustLifecycle? lifecycle;
  final List<TrustLimitation> limitations;
  final List<String> prohibitedInferences;
  // M1 Security Law: ALWAYS false. Server determines trust.
  final bool moneyControlsTrust;

  const TrustRecord({
    required this.publicId,
    required this.trustStateDigest,
    required this.subject,
    this.claimVerdicts = const [],
    this.evidence = const [],
    this.determination,
    this.continuity,
    this.freshness,
    this.authority,
    this.lifecycle,
    this.limitations = const [],
    this.prohibitedInferences = const [],
    this.moneyControlsTrust = false,
  });

  // M1-05: MTA1 R2 Ambiguity Defense.
  // UNQUALIFIED must NEVER render as T1 provenance.
  bool get isQualified {
    final det = determination;
    if (det == null) return false;
    if (!det.eligible) return false;
    if (det.qualificationState == QualificationState.unqualified) return false;
    return true;
  }

  // Returns null for UNQUALIFIED records — guarantees UNQUALIFIED_T1_OVERCLAIM = ZERO.
  int? get safeTier => isQualified ? determination?.tier : null;

  bool get hasContinuityGap {
    if (subject.continuityState.hasMaterialLimitation) return true;
    if (continuity?.state.hasMaterialLimitation ?? false) return true;
    return false;
  }

  bool get hasConflict => determination?.materialConflict ?? false;

  Map<String, dynamic> toJson() => {
        'public_id': publicId,
        'trust_state_digest': trustStateDigest,
        'subject': subject.toJson(),
        'claim_verdicts': claimVerdicts.map((c) => c.toJson()).toList(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        if (determination != null) 'determination': determination!.toJson(),
        if (continuity != null) 'continuity': continuity!.toJson(),
        if (freshness != null) 'freshness': freshness!.toJson(),
        if (authority != null) 'authority': authority!.toJson(),
        if (lifecycle != null) 'lifecycle': lifecycle!.toJson(),
        'limitations': limitations.map((l) => l.toJson()).toList(),
        'prohibited_inferences': prohibitedInferences,
        'money_controls_trust': moneyControlsTrust,
      };

  factory TrustRecord.fromJson(Map<String, dynamic> j) => TrustRecord(
        publicId: j['public_id'] as String? ?? '',
        trustStateDigest: j['trust_state_digest'] as String? ?? '',
        subject: TrustSubject.fromJson(j['subject'] as Map<String, dynamic>? ?? {}),
        claimVerdicts: (j['claim_verdicts'] as List?)
                ?.map((e) => ClaimVerdict.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        evidence: (j['evidence'] as List?)
                ?.map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        determination: j['determination'] != null
            ? TrustDetermination.fromJson(j['determination'] as Map<String, dynamic>)
            : null,
        continuity: j['continuity'] != null
            ? TrustContinuity.fromJson(j['continuity'] as Map<String, dynamic>)
            : null,
        freshness: j['freshness'] != null
            ? TrustFreshness.fromJson(j['freshness'] as Map<String, dynamic>)
            : null,
        authority: j['authority'] != null
            ? TrustAuthority.fromJson(j['authority'] as Map<String, dynamic>)
            : null,
        lifecycle: j['lifecycle'] != null
            ? TrustLifecycle.fromJson(j['lifecycle'] as Map<String, dynamic>)
            : null,
        limitations: (j['limitations'] as List?)
                ?.map((e) => TrustLimitation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        prohibitedInferences: (j['prohibited_inferences'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        moneyControlsTrust: j['money_controls_trust'] as bool? ?? false,
      );
}
