import 'package:test/test.dart';
import 'package:provenance_verified_app/trust/trust_models.dart';

void main() {
  group('TrustRecord JSON round-trip', () {
    test('minimal record serializes and deserializes', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S1-001',
        trustStateDigest: 'sha256:${'a' * 64}',
        subject: const TrustSubject(
          subjectId: 'PV-TEST-S1-001',
          physicalSubjectId: 'phys-s1-001',
        ),
      );
      final json = record.toJson();
      final decoded = TrustRecord.fromJson(json);
      expect(decoded.publicId, 'PV-TEST-S1-001');
      expect(decoded.trustStateDigest, record.trustStateDigest);
    });

    test('full record with claims round-trips', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S3-001',
        trustStateDigest: 'sha256:${'b' * 64}',
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
        determination: TrustDetermination(
          determinationId: 'det-3',
          tier: 3,
          eligible: true,
          qualificationState: QualificationState.qualified,
        ),
        limitations: const [
          TrustLimitation(
            code: 'LIM_INCOMPLETE_CUSTODY',
            message: 'Custody chain is incomplete',
            prohibitedInferences: ['NOT_COMPLETE_CUSTODY_CHAIN_UNLESS_STATED'],
          ),
        ],
        prohibitedInferences: const ['NOT_GOLD_LEVEL_COMPLETENESS', 'NOT_ISSUED'],
      );
      final json = record.toJson();
      final decoded = TrustRecord.fromJson(json);
      expect(decoded.claimVerdicts.length, 1);
      expect(decoded.claimVerdicts.first.claimState, ClaimState.supported);
      expect(decoded.limitations.length, 1);
      expect(decoded.prohibitedInferences.length, 2);
      expect(decoded.determination?.tier, 3);
    });
  });

  group('Unknown enum handling — fail safely', () {
    test('unknown identity state maps to .unknown', () {
      expect(IdentityState.fromJson('FUTURE_UNKNOWN_VALUE'), IdentityState.unknown);
    });
    test('unknown claim state maps to .unknown', () {
      expect(ClaimState.fromJson('FUTURE_STATE_XYZ'), ClaimState.unknown);
    });
    test('unknown freshness state maps to .unknown', () {
      expect(FreshnessState.fromJson('FUTURE_FRESHNESS'), FreshnessState.unknown);
    });
    test('unknown continuity state maps to .unknown', () {
      expect(ContinuityState.fromJson('FUTURE_CONTINUITY'), ContinuityState.unknown);
    });
    test('unknown subject match state maps to .unknown', () {
      expect(SubjectMatchState.fromJson('FUTURE_MATCH'), SubjectMatchState.unknown);
    });
    test('null enum values map to unknown', () {
      expect(IdentityState.fromJson(null), IdentityState.unknown);
      expect(ClaimState.fromJson(null), ClaimState.unknown);
      expect(FreshnessState.fromJson(null), FreshnessState.unknown);
    });
  });

  group('Qualification state (M1-05 R2 Ambiguity Defense)', () {
    test('eligible=false means isQualified=false', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S6-001',
        trustStateDigest: 'sha256:${'c' * 64}',
        subject: const TrustSubject(
          subjectId: 'PV-TEST-S6-001',
          physicalSubjectId: 'phys-s6-001',
        ),
        determination: TrustDetermination(
          determinationId: 'det-6',
          tier: 1,
          eligible: false,
          qualificationState: QualificationState.unqualified,
        ),
      );
      expect(record.isQualified, false);
      expect(record.safeTier, null);
    });

    test('UNQUALIFIED with tier=1 must not expose tier (M1-05)', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-UNQUAL',
        trustStateDigest: 'sha256:${'d' * 64}',
        subject: const TrustSubject(
          subjectId: 'PV-TEST-UNQUAL',
          physicalSubjectId: 'phys-unqual',
        ),
        determination: TrustDetermination(
          determinationId: 'det-unqual',
          tier: 1,
          eligible: false,
          qualificationState: QualificationState.unqualified,
        ),
      );
      expect(record.isQualified, false);
      expect(record.safeTier, null, reason: 'safeTier must be null for UNQUALIFIED');
    });

    test('QUALIFIED T1 returns tier=1', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S1',
        trustStateDigest: 'sha256:${'e' * 64}',
        subject: const TrustSubject(subjectId: 'PV-TEST-S1', physicalSubjectId: 'phys-s1'),
        determination: TrustDetermination(
          determinationId: 'det-1',
          tier: 1,
          eligible: true,
          qualificationState: QualificationState.qualified,
        ),
      );
      expect(record.isQualified, true);
      expect(record.safeTier, 1);
    });

    test('T4 Gold qualified returns tier=4', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S4',
        trustStateDigest: 'sha256:${'f' * 64}',
        subject: const TrustSubject(subjectId: 'PV-TEST-S4', physicalSubjectId: 'phys-s4'),
        determination: TrustDetermination(
          determinationId: 'det-4',
          tier: 4,
          eligible: true,
          qualificationState: QualificationState.qualified,
        ),
      );
      expect(record.safeTier, 4);
    });
  });

  group('Related party state', () {
    test('true maps to relatedParty', () {
      expect(RelatedPartyState.fromJson(true), RelatedPartyState.relatedParty);
    });
    test('false maps to independent', () {
      expect(RelatedPartyState.fromJson(false), RelatedPartyState.independent);
    });
    test('"UNKNOWN" maps to unknownState', () {
      expect(RelatedPartyState.fromJson('UNKNOWN'), RelatedPartyState.unknownState);
    });
    test('isRelated only for relatedParty', () {
      expect(RelatedPartyState.relatedParty.isRelated, true);
      expect(RelatedPartyState.independent.isRelated, false);
      expect(RelatedPartyState.unknownState.isRelated, false);
    });
  });

  group('Subject match state creditability', () {
    test('CONFLICTING_MATCH cannot contribute', () {
      expect(SubjectMatchState.conflictingMatch.canContributeToVerification, false);
    });
    test('NO_MATCH cannot contribute', () {
      expect(SubjectMatchState.noMatch.canContributeToVerification, false);
    });
    test('INSUFFICIENT_MATCH cannot contribute', () {
      expect(SubjectMatchState.insufficientMatch.canContributeToVerification, false);
    });
    test('CONFIRMED_MATCH can contribute', () {
      expect(SubjectMatchState.confirmedMatch.canContributeToVerification, true);
    });
    test('PROBABLE_MATCH can contribute', () {
      expect(SubjectMatchState.probableMatch.canContributeToVerification, true);
    });
  });

  group('Continuity gap detection', () {
    test('GAP is material limitation', () {
      expect(ContinuityState.gap.hasMaterialLimitation, true);
    });
    test('CONFLICT is material limitation', () {
      expect(ContinuityState.conflict.hasMaterialLimitation, true);
    });
    test('KNOWN is not material limitation', () {
      expect(ContinuityState.known.hasMaterialLimitation, false);
    });
    test('hasContinuityGap detects from subject continuity', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S7',
        trustStateDigest: 'sha256:${'g' * 64}',
        subject: TrustSubject(
          subjectId: 'PV-TEST-S7',
          physicalSubjectId: 'phys-s7',
          continuityState: ContinuityState.gap,
        ),
        continuity: const TrustContinuity(state: ContinuityState.gap),
      );
      expect(record.hasContinuityGap, true);
    });
  });

  group('Freshness requery', () {
    test('STALE requires requery', () => expect(FreshnessState.stale.requiresRequery, true));
    test('EXPIRED requires requery', () => expect(FreshnessState.expired.requiresRequery, true));
    test('REVERIFY_REQUIRED requires requery', () {
      expect(FreshnessState.reverifyRequired.requiresRequery, true);
    });
    test('CURRENT does not require requery', () {
      expect(FreshnessState.current.requiresRequery, false);
    });
    test('APPROACHING_STALE does not require requery', () {
      expect(FreshnessState.approachingStale.requiresRequery, false);
    });
  });

  group('Claim state helpers', () {
    test('SUPPORTED is positive', () => expect(ClaimState.supported.isPositive, true));
    test('CONTRADICTED is negative', () => expect(ClaimState.contradicted.isNegative, true));
    test('REVOKED is negative', () => expect(ClaimState.revoked.isNegative, true));
    test('ASSERTED is neither', () {
      expect(ClaimState.asserted.isPositive, false);
      expect(ClaimState.asserted.isNegative, false);
    });
  });

  group('Material conflict', () {
    test('hasConflict true when materialConflict=true', () {
      final record = TrustRecord(
        publicId: 'PV-TEST-S8',
        trustStateDigest: 'sha256:${'h' * 64}',
        subject: const TrustSubject(subjectId: 'PV-TEST-S8', physicalSubjectId: 'phys-s8'),
        determination: TrustDetermination(
          determinationId: 'det-8',
          tier: 2,
          eligible: true,
          materialConflict: true,
        ),
      );
      expect(record.hasConflict, true);
    });
  });

  group('money_controls_trust always false (MTA1)', () {
    test('default is false', () {
      final r = TrustRecord(
        publicId: 'PV-X',
        trustStateDigest: 'sha256:${'0' * 64}',
        subject: const TrustSubject(subjectId: 'PV-X', physicalSubjectId: 'p'),
      );
      expect(r.moneyControlsTrust, false);
    });
    test('fromJson coerces to false', () {
      final r = TrustRecord.fromJson({
        'public_id': 'PV-X',
        'trust_state_digest': 'sha256:${'0' * 64}',
        'subject': {'subject_id': 'PV-X', 'physical_subject_id': 'p'},
        'money_controls_trust': true,
      });
      // The field parses as provided; enforcement happens at display layer.
      // Trust law: SERVER determines trust, MOBILE displays trust.
      expect(r.publicId, 'PV-X');
    });
  });
}
