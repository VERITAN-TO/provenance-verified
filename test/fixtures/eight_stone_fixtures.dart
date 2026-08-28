import 'package:provenance_verified_app/trust/trust_models.dart';

// Eight-stone deterministic corpus.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

const _p = 'sha256:';
const _s1d = '${_p}aaaa000000000000000000000000000000000000000000000000000000000001';
const _s2d = '${_p}bbbb000000000000000000000000000000000000000000000000000000000002';
const _s3d = '${_p}cccc000000000000000000000000000000000000000000000000000000000003';
const _s4d = '${_p}dddd000000000000000000000000000000000000000000000000000000000004';
const _s5d = '${_p}eeee000000000000000000000000000000000000000000000000000000000005';
const _s6d = '${_p}ffff000000000000000000000000000000000000000000000000000000000006';
const _s7d = '${_p}1111000000000000000000000000000000000000000000000000000000000007';
const _s8d = '${_p}2222000000000000000000000000000000000000000000000000000000000008';

// STONE-1: T1 — Asset Fingerprint Only
TrustRecord stone1T1AssetFingerprint() => TrustRecord(
      publicId: 'PV-TEST-S1-001',
      trustStateDigest: _s1d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S1-001',
        physicalSubjectId: 'phys-s1-001',
        identityState: IdentityState.resolved,
        continuityState: ContinuityState.known,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c1-fingerprint',
          predicate: 'asset_fingerprint',
          assertedValue: 'HASH-S1-RUBY-001',
          claimState: ClaimState.supported,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e1-photo',
          type: 'photographic_record',
          source: 'GemLab-London',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s1',
        tier: 1,
        eligible: true,
        qualificationState: QualificationState.qualified,
        metRequirements: ['ASSET_FINGERPRINT_PRESENT', 'IDENTITY_RESOLVED'],
        notMetRequirements: ['INDEPENDENT_PROVENANCE_EVIDENCE', 'CHAIN_OF_CUSTODY_COMPLETE'],
      ),
      prohibitedInferences: const [
        'NOT_PROVENANCE_VERIFIED',
        'NOT_INDEPENDENT_VERIFICATION',
        'NOT_COMPLETE_CUSTODY_CHAIN_UNLESS_STATED',
      ],
      moneyControlsTrust: false,
    );

// STONE-2: T2 — Declared Provenance, Not Independently Verified
TrustRecord stone2T2DeclaredProvenance() => TrustRecord(
      publicId: 'PV-TEST-S2-001',
      trustStateDigest: _s2d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S2-001',
        physicalSubjectId: 'phys-s2-001',
        identityState: IdentityState.resolved,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c2-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Colombia',
          claimState: ClaimState.asserted,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e2-cert',
          type: 'seller_declaration',
          source: 'Seller',
          integrityVerificationState: IntegrityVerificationState.presentUnverified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.relatedParty,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s2',
        tier: 2,
        eligible: true,
        qualificationState: QualificationState.qualified,
        metRequirements: ['IDENTITY_RESOLVED', 'PROVENANCE_CLAIMS_PRESENT'],
        notMetRequirements: ['INDEPENDENT_EVIDENCE_REQUIRED_FOR_T3'],
      ),
      limitations: const [
        TrustLimitation(
          code: 'LIM_UNVERIFIED_CLAIMS',
          message: 'Claims are declared by seller only.',
          prohibitedInferences: ['NOT_INDEPENDENTLY_VERIFIED'],
        ),
      ],
      prohibitedInferences: const ['NOT_INDEPENDENTLY_VERIFIED'],
      moneyControlsTrust: false,
    );

// STONE-3: T3 — Evidence-Verified Within Scope
TrustRecord stone3T3EvidenceVerified() => TrustRecord(
      publicId: 'PV-TEST-S3-001',
      trustStateDigest: _s3d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S3-001',
        physicalSubjectId: 'phys-s3-001',
        identityState: IdentityState.resolved,
        continuityState: ContinuityState.partial,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c3-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Mozambique',
          claimState: ClaimState.supported,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e3-grs',
          type: 'gemmological_certificate',
          source: 'GRS Gemresearch Swisslab',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
        EvidenceItem(
          evidenceId: 'e3-gia',
          type: 'gemmological_report',
          source: 'GIA',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s3',
        tier: 3,
        eligible: true,
        qualificationState: QualificationState.qualified,
        metRequirements: ['IDENTITY_RESOLVED', 'INDEPENDENT_EVIDENCE_PRESENT', 'CLAIMS_CORROBORATED'],
        notMetRequirements: ['COMPLETE_CUSTODY_CHAIN', 'COMPLETE_PV_PROFILE'],
      ),
      continuity: const TrustContinuity(
        state: ContinuityState.partial,
        gapDescription: 'Pre-2018 custody not documented.',
      ),
      prohibitedInferences: const ['NOT_GOLD_LEVEL_COMPLETENESS'],
      moneyControlsTrust: false,
    );

// STONE-4: T4 Gold — PV Gold Seal
TrustRecord stone4T4Gold() => TrustRecord(
      publicId: 'PV-TEST-S4-001',
      trustStateDigest: _s4d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S4-001',
        physicalSubjectId: 'phys-s4-001',
        identityState: IdentityState.resolved,
        continuityState: ContinuityState.known,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c4-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Kashmir',
          claimState: ClaimState.supported,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e4-grs',
          type: 'gemmological_certificate',
          source: 'GRS',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
        EvidenceItem(
          evidenceId: 'e4-gia',
          type: 'gemmological_report',
          source: 'GIA',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
        EvidenceItem(
          evidenceId: 'e4-pv',
          type: 'pv_audit_record',
          source: 'Provenance Verified Ltd',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s4',
        tier: 4,
        eligible: true,
        qualificationState: QualificationState.qualified,
        notMetRequirements: [],
        metRequirements: [
          'IDENTITY_RESOLVED',
          'INDEPENDENT_EVIDENCE_PRESENT',
          'CLAIMS_CORROBORATED',
          'COMPLETE_CUSTODY_CHAIN',
          'COMPLETE_PV_PROFILE',
          'NO_MATERIAL_CONFLICTS',
        ],
      ),
      continuity: const TrustContinuity(state: ContinuityState.known),
      prohibitedInferences: const ['NOT_ABSOLUTE_TRUTH', 'NOT_GOVERNMENT_CERTIFICATION'],
      moneyControlsTrust: false,
    );

// STONE-5: Related-Party Trap
TrustRecord stone5RelatedPartyTrap() => TrustRecord(
      publicId: 'PV-TEST-S5-001',
      trustStateDigest: _s5d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S5-001',
        physicalSubjectId: 'phys-s5-001',
        identityState: IdentityState.resolved,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c5-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Burma',
          claimState: ClaimState.asserted,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e5-seller-cert',
          type: 'seller_certificate',
          source: 'Gem Dealer XYZ',
          integrityVerificationState: IntegrityVerificationState.presentUnverified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.relatedParty,
        ),
        EvidenceItem(
          evidenceId: 'e5-dealer-note',
          type: 'dealer_note',
          source: 'Gem Dealer XYZ Subsidiary',
          integrityVerificationState: IntegrityVerificationState.presentUnverified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.relatedParty,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s5',
        tier: 2,
        eligible: true,
        qualificationState: QualificationState.qualified,
        notMetRequirements: ['INDEPENDENT_EVIDENCE_REQUIRED_FOR_T3'],
      ),
      limitations: const [
        TrustLimitation(
          code: 'LIM_ALL_EVIDENCE_RELATED_PARTY',
          message: 'All submitted evidence is from related parties.',
          prohibitedInferences: ['NOT_INDEPENDENTLY_VERIFIED', 'NOT_THIRD_PARTY_CORROBORATED'],
        ),
      ],
      prohibitedInferences: const ['NOT_INDEPENDENTLY_VERIFIED', 'NOT_THIRD_PARTY_CORROBORATED'],
      moneyControlsTrust: false,
    );

// STONE-6: Wrong Subject — UNQUALIFIED
TrustRecord stone6WrongSubject() => TrustRecord(
      publicId: 'PV-TEST-S6-001',
      trustStateDigest: _s6d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S6-001',
        physicalSubjectId: 'phys-s6-UNRESOLVED',
        identityState: IdentityState.ambiguous,
        subjectMatchState: SubjectMatchState.conflictingMatch,
      ),
      determination: TrustDetermination(
        determinationId: 'det-s6',
        tier: 1,
        eligible: false,
        qualificationState: QualificationState.unqualified,
      ),
      limitations: const [
        TrustLimitation(
          code: 'LIM_IDENTITY_UNRESOLVED',
          message: 'Subject identity could not be uniquely resolved.',
          prohibitedInferences: ['NOT_UNIQUELY_IDENTIFIED', 'NOT_QUALIFIED_FOR_RELIANCE'],
        ),
      ],
      prohibitedInferences: const ['NOT_UNIQUELY_IDENTIFIED', 'NOT_QUALIFIED_FOR_RELIANCE'],
      moneyControlsTrust: false,
    );

// STONE-7: Custody Gap
TrustRecord stone7CustodyGap() => TrustRecord(
      publicId: 'PV-TEST-S7-001',
      trustStateDigest: _s7d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S7-001',
        physicalSubjectId: 'phys-s7-001',
        identityState: IdentityState.resolved,
        continuityState: ContinuityState.gap,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c7-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Sri Lanka',
          claimState: ClaimState.supported,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e7-grs',
          type: 'gemmological_certificate',
          source: 'GRS Gemresearch Swisslab',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s7',
        tier: 3,
        eligible: true,
        qualificationState: QualificationState.qualified,
        notMetRequirements: ['COMPLETE_CUSTODY_CHAIN'],
      ),
      continuity: const TrustContinuity(
        state: ContinuityState.gap,
        gapDescription: 'No custody documentation for 2001–2010.',
      ),
      limitations: const [
        TrustLimitation(
          code: 'LIM_CUSTODY_GAP_2001_2010',
          message: 'A material custody gap exists for the period 2001–2010.',
          prohibitedInferences: ['NOT_CONTINUOUS_CUSTODY_CHAIN_UNLESS_STATED'],
        ),
      ],
      prohibitedInferences: const [
        'NOT_CONTINUOUS_CUSTODY_CHAIN_UNLESS_STATED',
        'NOT_COMPLETE_CUSTODY_CHAIN_UNLESS_STATED',
      ],
      moneyControlsTrust: false,
    );

// STONE-8: Material Contradiction
TrustRecord stone8Contradiction() => TrustRecord(
      publicId: 'PV-TEST-S8-001',
      trustStateDigest: _s8d,
      subject: TrustSubject(
        subjectId: 'PV-TEST-S8-001',
        physicalSubjectId: 'phys-s8-001',
        identityState: IdentityState.resolved,
      ),
      claimVerdicts: const [
        ClaimVerdict(
          claimId: 'c8-origin',
          predicate: 'geographic_origin',
          assertedValue: 'Thailand',
          claimState: ClaimState.contradicted,
          material: true,
        ),
        ClaimVerdict(
          claimId: 'c8-treatment',
          predicate: 'heat_treatment',
          assertedValue: 'none',
          claimState: ClaimState.contradicted,
          material: true,
        ),
      ],
      evidence: const [
        EvidenceItem(
          evidenceId: 'e8-gia',
          type: 'gemmological_report',
          source: 'GIA',
          integrityVerificationState: IntegrityVerificationState.verified,
          subjectMatchState: SubjectMatchState.confirmedMatch,
          relatedParty: RelatedPartyState.independent,
        ),
      ],
      determination: TrustDetermination(
        determinationId: 'det-s8',
        tier: 2,
        eligible: true,
        qualificationState: QualificationState.qualified,
        materialConflict: true,
        notMetRequirements: ['CLAIMS_CORROBORATED', 'NO_MATERIAL_CONFLICTS'],
      ),
      limitations: const [
        TrustLimitation(
          code: 'LIM_MATERIAL_CONFLICT',
          message: 'GIA report contradicts declared origin and treatment claims.',
          prohibitedInferences: ['NOT_CLAIMS_VERIFIED', 'NOT_CORROBORATED_ORIGIN'],
        ),
      ],
      prohibitedInferences: const ['NOT_CLAIMS_VERIFIED', 'NOT_CORROBORATED_ORIGIN'],
      moneyControlsTrust: false,
    );

Map<String, TrustRecord Function()> allStones = {
  'STONE-1-T1': stone1T1AssetFingerprint,
  'STONE-2-T2': stone2T2DeclaredProvenance,
  'STONE-3-T3': stone3T3EvidenceVerified,
  'STONE-4-T4-GOLD': stone4T4Gold,
  'STONE-5-RELATED-PARTY': stone5RelatedPartyTrap,
  'STONE-6-WRONG-SUBJECT': stone6WrongSubject,
  'STONE-7-CUSTODY-GAP': stone7CustodyGap,
  'STONE-8-CONTRADICTION': stone8Contradiction,
};
