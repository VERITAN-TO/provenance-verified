import 'package:test/test.dart';
import 'package:provenance_verified_app/trust/trust_models.dart';
import '../fixtures/eight_stone_fixtures.dart';

// M1-23: MOBILE_MACHINE_PARITY = 8/8 required.

void main() {
  group('STONE-1: T1 Asset Fingerprint', () {
    late TrustRecord s;
    setUp(() => s = stone1T1AssetFingerprint());

    test('publicId', () => expect(s.publicId, 'PV-TEST-S1-001'));
    test('tier=1 qualified', () {
      expect(s.safeTier, 1);
      expect(s.isQualified, true);
    });
    test('money_controls_trust=false', () => expect(s.moneyControlsTrust, false));
    test('no related-party evidence', () {
      for (final e in s.evidence) {
        expect(e.relatedParty, isNot(RelatedPartyState.relatedParty));
      }
    });
    test('NOT_PROVENANCE_VERIFIED prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_PROVENANCE_VERIFIED'));
    });
    test('JSON round-trip preserves tier=1', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.safeTier, 1);
    });
  });

  group('STONE-2: T2 Declared Provenance', () {
    late TrustRecord s;
    setUp(() => s = stone2T2DeclaredProvenance());

    test('tier=2 qualified', () {
      expect(s.safeTier, 2);
      expect(s.isQualified, true);
    });
    test('all claims ASSERTED (not SUPPORTED)', () {
      for (final c in s.claimVerdicts) {
        expect(c.claimState, ClaimState.asserted);
      }
    });
    test('all evidence is related-party', () {
      for (final e in s.evidence) {
        expect(e.relatedParty, RelatedPartyState.relatedParty);
      }
    });
    test('NOT_INDEPENDENTLY_VERIFIED prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_INDEPENDENTLY_VERIFIED'));
    });
    test('JSON round-trip', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.claimVerdicts.first.claimState, ClaimState.asserted);
    });
  });

  group('STONE-3: T3 Evidence-Verified', () {
    late TrustRecord s;
    setUp(() => s = stone3T3EvidenceVerified());

    test('tier=3 qualified', () {
      expect(s.safeTier, 3);
      expect(s.isQualified, true);
    });
    test('all evidence independent', () {
      for (final e in s.evidence) {
        expect(e.relatedParty, RelatedPartyState.independent);
      }
    });
    test('all evidence integrity verified', () {
      for (final e in s.evidence) {
        expect(e.integrityVerificationState, IntegrityVerificationState.verified);
      }
    });
    test('continuity is partial (not gap)', () {
      expect(s.subject.continuityState, ContinuityState.partial);
    });
    test('hasContinuityGap false (partial != gap)', () {
      expect(s.hasContinuityGap, false);
    });
    test('JSON round-trip: 2 evidence items', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.evidence.length, 2);
    });
  });

  group('STONE-4: T4 Gold', () {
    late TrustRecord s;
    setUp(() => s = stone4T4Gold());

    test('tier=4 qualified', () {
      expect(s.safeTier, 4);
      expect(s.isQualified, true);
    });
    test('notMetRequirements is empty', () {
      expect(s.determination!.notMetRequirements, isEmpty);
    });
    test('hasConflict=false', () => expect(s.hasConflict, false));
    test('continuity=KNOWN', () {
      expect(s.continuity?.state, ContinuityState.known);
    });
    test('3 independent evidence items', () {
      expect(s.evidence.length, 3);
      for (final e in s.evidence) {
        expect(e.relatedParty, RelatedPartyState.independent);
      }
    });
    test('NOT_ABSOLUTE_TRUTH prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_ABSOLUTE_TRUTH'));
    });
  });

  group('STONE-5: Related-Party Trap', () {
    late TrustRecord s;
    setUp(() => s = stone5RelatedPartyTrap());

    test('tier=2 despite evidence', () => expect(s.safeTier, 2));
    test('ALL evidence is related-party', () {
      expect(s.evidence, isNotEmpty);
      for (final e in s.evidence) {
        expect(e.relatedParty, RelatedPartyState.relatedParty);
      }
    });
    test('LIM_ALL_EVIDENCE_RELATED_PARTY present', () {
      final codes = s.limitations.map((l) => l.code).toList();
      expect(codes, contains('LIM_ALL_EVIDENCE_RELATED_PARTY'));
    });
    test('NOT_INDEPENDENTLY_VERIFIED prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_INDEPENDENTLY_VERIFIED'));
    });
  });

  group('STONE-6: Wrong Subject (UNQUALIFIED)', () {
    late TrustRecord s;
    setUp(() => s = stone6WrongSubject());

    test('eligible=false', () => expect(s.determination!.eligible, false));
    test('qualificationState=UNQUALIFIED', () {
      expect(s.determination!.qualificationState, QualificationState.unqualified);
    });
    test('isQualified=false', () => expect(s.isQualified, false));
    test('safeTier=null (M1-05: UNQUALIFIED_T1_OVERCLAIM=ZERO)', () {
      expect(s.safeTier, null);
    });
    test('identity=AMBIGUOUS', () {
      expect(s.subject.identityState, IdentityState.ambiguous);
    });
    test('NOT_UNIQUELY_IDENTIFIED prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_UNIQUELY_IDENTIFIED'));
    });
    test('JSON round-trip: stays UNQUALIFIED', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.isQualified, false);
      expect(s2.safeTier, null);
    });
  });

  group('STONE-7: Custody Gap', () {
    late TrustRecord s;
    setUp(() => s = stone7CustodyGap());

    test('tier=3 despite gap', () {
      expect(s.safeTier, 3);
      expect(s.isQualified, true);
    });
    test('continuity.state=GAP', () {
      expect(s.continuity!.state, ContinuityState.gap);
    });
    test('hasContinuityGap=true', () => expect(s.hasContinuityGap, true));
    test('gap has description', () {
      expect(s.continuity!.gapDescription, isNotNull);
      expect(s.continuity!.gapDescription, isNotEmpty);
    });
    test('CUSTODY_GAP limitation present', () {
      final codes = s.limitations.map((l) => l.code).toList();
      expect(codes.any((c) => c.contains('CUSTODY_GAP')), true);
    });
    test('GAP.hasMaterialLimitation=true', () {
      expect(ContinuityState.gap.hasMaterialLimitation, true);
    });
    test('JSON round-trip: continuity preserved', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.continuity?.state, ContinuityState.gap);
    });
  });

  group('STONE-8: Material Contradiction', () {
    late TrustRecord s;
    setUp(() => s = stone8Contradiction());

    test('tier=2 due to conflict', () => expect(s.safeTier, 2));
    test('materialConflict=true', () {
      expect(s.determination!.materialConflict, true);
    });
    test('hasConflict=true', () => expect(s.hasConflict, true));
    test('CONTRADICTED claims present', () {
      final contradicted = s.claimVerdicts
          .where((c) => c.claimState == ClaimState.contradicted)
          .toList();
      expect(contradicted, isNotEmpty);
    });
    test('CONTRADICTED.isNegative=true', () {
      expect(ClaimState.contradicted.isNegative, true);
    });
    test('NOT_CLAIMS_VERIFIED prohibited', () {
      expect(s.prohibitedInferences, contains('NOT_CLAIMS_VERIFIED'));
    });
    test('JSON round-trip: materialConflict preserved', () {
      final s2 = TrustRecord.fromJson(s.toJson());
      expect(s2.determination!.materialConflict, true);
      expect(s2.hasConflict, true);
    });
  });

  test('All 8 stones in corpus map', () {
    expect(allStones.length, 8);
    for (final entry in allStones.entries) {
      final stone = entry.value();
      expect(stone.publicId, isNotEmpty, reason: '${entry.key} must have publicId');
      expect(stone.trustStateDigest, startsWith('sha256:'),
          reason: '${entry.key} must have valid digest');
      expect(stone.moneyControlsTrust, false,
          reason: '${entry.key}: money_controls_trust MUST be false per MTA1');
    }
  });
}
