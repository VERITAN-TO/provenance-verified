// M2: MachineTrustResponse parsing, mapping, and security law tests.
// M2-01: pv.machine-trust.v1 schema parses correctly from real server format.
// M2-02: trust_state_digest extracted from x-pv-trust-state-digest header.
// M2-03: physical_subject_id extracted from x-pv-physical-subject header.
// M2-04: moneyControlsTrust = false always enforced.
// M2-05: UNQUALIFIED records: safeTier = null (UNQUALIFIED_T1_OVERCLAIM = ZERO).
// M2-06: Error responses parse correctly and are fail-closed.
// M2-07: Stale trust state digest detected correctly.
// M2-08: Freshness state maps correctly from server response.

import 'package:test/test.dart';
import 'package:provenance_verified_app/trust/machine_trust_response.dart';
import 'package:provenance_verified_app/trust/trust_models.dart';
import 'package:provenance_verified_app/actionability/actionability_models.dart';
import 'package:provenance_verified_app/reliance/receipt_models.dart';

Map<String, dynamic> _realServerPayload({
  String determinationId = 'det-m2-001',
  int tier = 3,
  String tierLabel = 'T3 — Evidence-Verified',
  bool eligible = true,
  bool materialConflict = false,
  bool current = true,
  String freshnessState = 'CURRENT',
  String identityState = 'RESOLVED',
  String continuityState = 'PARTIAL',
  List<Map<String, dynamic>>? claims,
  List<Map<String, dynamic>>? limitations,
  List<String>? prohibitedInferences,
}) => {
  'schema': 'pv.machine-trust.v1',
  'subject': {
    'subject_id': 'PV-QUAL-001',
    'subject_type': 'gem',
    'identity_state': identityState,
  },
  'claims': claims ?? [
    {
      'claim_id': 'c-origin',
      'predicate': 'geographic_origin',
      'state': 'SUPPORTED',
      'supporting_evidence': ['ev-001', 'ev-002'],
    },
  ],
  'policy': {
    'policy_id': 'pol-v1',
    'policy_version': 'PV-POLICY-2026.08-V4-R1',
    'policy_digest': 'sha256:abcdef1234',
  },
  'determination': {
    'determination_id': determinationId,
    'tier': tier,
    'tier_label': tierLabel,
    'current': current,
    'determination_digest': 'sha256:det001',
    'eligible': eligible,
    'material_conflict': materialConflict,
  },
  'limitations': limitations ?? [],
  'allowed_claims': [],
  'prohibited_inferences': prohibitedInferences ?? ['NOT_ABSOLUTE_TRUTH'],
  'freshness': {
    'state': freshnessState,
    'as_of': '2026-08-28T10:00:00Z',
    'valid_until': '2026-09-28T10:00:00Z',
    'requery_after': null,
  },
  'authority': {
    'determination_authoritative': true,
    'issuance_authorized': true,
    'authority_state': 'ACTIVE',
  },
  'integrity': {
    'evidence_manifest_valid': true,
    'determination_digest_valid': true,
    'credential_signature_valid': true,
  },
  'credential': {
    'credential_id': 'cred-001',
    'status': 'ACTIVE',
    'authoritative': true,
  },
  'continuity': {'state': continuityState},
  'lifecycle': {'state': 'ACTIVE'},
  'as_of': '2026-08-28T10:00:00Z',
  'served_at': '2026-08-28T10:00:01Z',
};

void main() {
  const kDigest = 'sha256:aaaa0000000000000000000000000000000000000000000000000000deadbeef';
  const kPhysicalId = 'phys-qual-001';

  // ── M2-01: Basic schema parsing ───────────────────────────────────────────

  group('M2-01: pv.machine-trust.v1 schema parsing', () {
    late MachineTrustResponse r;
    setUp(() {
      r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
    });

    test('schema field', () => expect(r.schema, 'pv.machine-trust.v1'));
    test('subjectId', () => expect(r.subjectId, 'PV-QUAL-001'));
    test('identityState', () => expect(r.identityState, 'RESOLVED'));
    test('tier', () => expect(r.tier, 3));
    test('eligible=true', () => expect(r.eligible, true));
    test('materialConflict=false', () => expect(r.materialConflict, false));
    test('freshnessState=CURRENT', () => expect(r.freshnessState, 'CURRENT'));
    test('policyVersion', () => expect(r.policyVersion, 'PV-POLICY-2026.08-V4-R1'));
    test('claims parsed', () {
      expect(r.claims.length, 1);
      expect(r.claims.first.predicate, 'geographic_origin');
      expect(r.claims.first.state, 'SUPPORTED');
    });
    test('prohibitedInferences', () => expect(r.prohibitedInferences, contains('NOT_ABSOLUTE_TRUTH')));
    test('no error', () => expect(r.hasError, false));
  });

  // ── M2-02: trust_state_digest from header ─────────────────────────────────

  group('M2-02: trust_state_digest from x-pv-trust-state-digest header', () {
    test('uses header value when present', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      expect(r.trustStateDigest, kDigest);
    });

    test('falls back to determination_digest when header empty', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: '',
        physicalSubjectHeader: kPhysicalId,
      );
      expect(r.trustStateDigest, 'sha256:det001');
    });

    test('digest starts with sha256:', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      expect(r.trustStateDigest, startsWith('sha256:'));
    });
  });

  // ── M2-03: physical_subject_id from header ────────────────────────────────

  group('M2-03: physical_subject_id from x-pv-physical-subject header', () {
    test('uses header value when present', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      expect(r.physicalSubjectId, kPhysicalId);
    });

    test('falls back to subject_id when header empty', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: '',
      );
      expect(r.physicalSubjectId, 'PV-QUAL-001');
    });
  });

  // ── M2-04: moneyControlsTrust = false always ──────────────────────────────

  group('M2-04: moneyControlsTrust = false (MTA1 security law)', () {
    test('toTrustRecord: moneyControlsTrust always false', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.moneyControlsTrust, false);
    });

    test('moneyControlsTrust false even when tier=4', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(tier: 4, tierLabel: 'T4 Gold'),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.moneyControlsTrust, false);
    });
  });

  // ── M2-05: UNQUALIFIED records → safeTier = null ──────────────────────────

  group('M2-05: UNQUALIFIED_T1_OVERCLAIM = ZERO', () {
    test('eligible=false → isQualified=false', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(eligible: false),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.isQualified, false);
    });

    test('eligible=false → safeTier=null (M1-05 enforced)', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(eligible: false, tier: 1),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.safeTier, null);
    });

    test('eligible=true, tier=3 → safeTier=3', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(eligible: true, tier: 3),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.safeTier, 3);
    });
  });

  // ── M2-06: Error response handling ────────────────────────────────────────

  group('M2-06: Error response fail-closed', () {
    test('error payload detected', () {
      final r = MachineTrustResponse.fromJson(
        {
          'schema': 'pv.machine-trust.v1',
          'error': {'code': 'INSUFFICIENT_SCOPE', 'message': 'Requires trust:read scope.'},
        },
        trustStateDigestHeader: '',
        physicalSubjectHeader: '',
      );
      expect(r.hasError, true);
      expect(r.errorCode, 'INSUFFICIENT_SCOPE');
    });

    test('missing determination → eligible defaults false', () {
      final r = MachineTrustResponse.fromJson(
        {'schema': 'pv.machine-trust.v1'},
        trustStateDigestHeader: '',
        physicalSubjectHeader: '',
      );
      expect(r.eligible, false);
      final tr = r.toTrustRecord('PV-UNKNOWN');
      expect(tr.isQualified, false);
      expect(tr.safeTier, null);
    });
  });

  // ── M2-07: Stale digest detection ─────────────────────────────────────────

  group('M2-07: Stale receipt digest detection', () {
    test('receipt is stale when digest changes', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      final receipt = RelianceReceipt(
        receiptId: 'rr-001',
        publicId: 'PV-QUAL-001',
        physicalSubjectId: kPhysicalId,
        trustStateDigest: kDigest,
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime(2026),
        validityState: ReceiptValidityState.valid,
      );

      // Same digest → not stale
      expect(receipt.isStaleFor(tr.trustStateDigest), false);

      // Changed digest → stale
      const newDigest = 'sha256:bbbb1111111111111111111111111111111111111111111111111111newdigest';
      expect(receipt.isStaleFor(newDigest), true);
    });

    test('invalidated receipt has INVALIDATED state', () {
      final receipt = RelianceReceipt(
        receiptId: 'rr-002',
        publicId: 'PV-QUAL-001',
        physicalSubjectId: kPhysicalId,
        trustStateDigest: kDigest,
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime(2026),
        validityState: ReceiptValidityState.valid,
      );
      final invalidated = receipt.invalidate();
      expect(invalidated.validityState, ReceiptValidityState.invalidated);
    });

    test('stale receipt JSON round-trip preserves digest', () {
      final receipt = RelianceReceipt(
        receiptId: 'rr-003',
        publicId: 'PV-QUAL-001',
        physicalSubjectId: kPhysicalId,
        trustStateDigest: kDigest,
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime(2026),
        validityState: ReceiptValidityState.valid,
      );
      final r2 = RelianceReceipt.fromJson(receipt.toJson());
      expect(r2.trustStateDigest, kDigest);
    });
  });

  // ── M2-08: Freshness state mapping ────────────────────────────────────────

  group('M2-08: Freshness state mapping', () {
    void testFreshness(String serverState, FreshnessState expected) {
      test('$serverState → $expected', () {
        final r = MachineTrustResponse.fromJson(
          _realServerPayload(freshnessState: serverState),
          trustStateDigestHeader: kDigest,
          physicalSubjectHeader: kPhysicalId,
        );
        final tr = r.toTrustRecord('PV-QUAL-001');
        expect(tr.freshness?.state, expected);
      });
    }

    testFreshness('CURRENT', FreshnessState.current);
    testFreshness('APPROACHING_STALE', FreshnessState.approachingStale);
    testFreshness('STALE', FreshnessState.stale);
    testFreshness('EXPIRED', FreshnessState.expired);
    testFreshness('REVERIFY_REQUIRED', FreshnessState.reverifyRequired);
    testFreshness('UNKNOWN', FreshnessState.unknown);

    test('STALE.requiresRequery = true', () {
      expect(FreshnessState.stale.requiresRequery, true);
    });

    test('CURRENT.requiresRequery = false', () {
      expect(FreshnessState.current.requiresRequery, false);
    });
  });

  // ── M2-09: Full round-trip TrustRecord from real server response ──────────

  group('M2-09: TrustRecord mapping from MachineTrustResponse', () {
    test('publicId preserved', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.publicId, 'PV-QUAL-001');
    });

    test('trustStateDigest from header', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.trustStateDigest, kDigest);
    });

    test('physicalSubjectId from header', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.subject.physicalSubjectId, kPhysicalId);
    });

    test('identity RESOLVED maps correctly', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(identityState: 'RESOLVED'),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.subject.identityState, IdentityState.resolved);
    });

    test('material conflict propagates', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(materialConflict: true),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.hasConflict, true);
    });

    test('SUPPORTED claim maps to ClaimState.supported', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.claimVerdicts.isNotEmpty, true);
      expect(tr.claimVerdicts.first.claimState, ClaimState.supported);
    });

    test('limitations preserved', () {
      final r = MachineTrustResponse.fromJson(
        _realServerPayload(limitations: [
          {'code': 'LIM_TEST', 'message': 'Test limitation'},
        ]),
        trustStateDigestHeader: kDigest,
        physicalSubjectHeader: kPhysicalId,
      );
      final tr = r.toTrustRecord('PV-QUAL-001');
      expect(tr.limitations.any((l) => l.code == 'LIM_TEST'), true);
    });
  });

  // ── M2-10: isServerIssued receipt flag ────────────────────────────────────

  group('M2-10: Server-issued vs local receipt', () {
    test('isServerIssued=true parses from JSON', () {
      final r = RelianceReceipt.fromJson({
        'receipt_id': 'rr-server',
        'public_id': 'PV-QUAL-001',
        'physical_subject_id': kPhysicalId,
        'trust_state_digest': kDigest,
        'purpose': 'PURCHASE',
        'decision': 'ALLOW',
        'limitations': [],
        'prohibited_inferences': [],
        'created_at': '2026-08-28T10:00:00.000Z',
        'validity_state': 'VALID',
        'is_server_issued': true,
      });
      expect(r.isServerIssued, true);
    });

    test('isServerIssued defaults false', () {
      final r = RelianceReceipt(
        receiptId: 'rr-local',
        publicId: 'PV-QUAL-001',
        physicalSubjectId: kPhysicalId,
        trustStateDigest: kDigest,
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime(2026),
      );
      expect(r.isServerIssued, false);
    });
  });
}
