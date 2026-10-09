// Runtime behavioral tests for activity_models.dart fail-closed properties.
// These complement the M4 static-contract suite (source-text scanning) with
// actual runtime verification of security-critical parsing behavior.

import 'package:test/test.dart';
import 'package:provenance_verified_app/activity/models/activity_models.dart';

void main() {
  // ── CredentialLifecycleStatus.fromApiString — fail-closed ─────────────────

  group('CredentialLifecycleStatus.fromApiString: fail-closed', () {
    test('null → null (determination not yet available)', () {
      expect(CredentialLifecycleStatus.fromApiString(null), isNull);
    });

    test('"ACTIVE" → active', () {
      expect(
        CredentialLifecycleStatus.fromApiString('ACTIVE'),
        CredentialLifecycleStatus.active,
      );
    });

    test('"NOT_ISSUED" → notIssued', () {
      expect(
        CredentialLifecycleStatus.fromApiString('NOT_ISSUED'),
        CredentialLifecycleStatus.notIssued,
      );
    });

    test('"REVOKED" → revoked', () {
      expect(
        CredentialLifecycleStatus.fromApiString('REVOKED'),
        CredentialLifecycleStatus.revoked,
      );
    });

    test('"SUSPENDED" → suspended', () {
      expect(
        CredentialLifecycleStatus.fromApiString('SUSPENDED'),
        CredentialLifecycleStatus.suspended,
      );
    });

    test('"CREDENTIAL_AUTHORITY_UNAVAILABLE" → authorityUnavailable', () {
      expect(
        CredentialLifecycleStatus.fromApiString('CREDENTIAL_AUTHORITY_UNAVAILABLE'),
        CredentialLifecycleStatus.authorityUnavailable,
      );
    });

    test('"REGISTRY_AUTHORITY_UNAVAILABLE" → authorityUnavailable', () {
      expect(
        CredentialLifecycleStatus.fromApiString('REGISTRY_AUTHORITY_UNAVAILABLE'),
        CredentialLifecycleStatus.authorityUnavailable,
      );
    });

    test('unrecognized string → authorityUnavailable (fail-closed, not null, not notIssued)', () {
      expect(
        CredentialLifecycleStatus.fromApiString('SOMETHING_UNEXPECTED'),
        CredentialLifecycleStatus.authorityUnavailable,
      );
    });
  });

  // ── SettlementPaymentStatus.fromApiString — fail-closed ───────────────────

  group('SettlementPaymentStatus.fromApiString: fail-closed', () {
    test('null → null', () {
      expect(SettlementPaymentStatus.fromApiString(null), isNull);
    });

    test('"FREE" → free', () {
      expect(SettlementPaymentStatus.fromApiString('FREE'), SettlementPaymentStatus.free);
    });

    test('"PAID" → paid', () {
      expect(SettlementPaymentStatus.fromApiString('PAID'), SettlementPaymentStatus.paid);
    });

    test('"PENDING" → pending', () {
      expect(
        SettlementPaymentStatus.fromApiString('PENDING'),
        SettlementPaymentStatus.pending,
      );
    });

    test('"LOOKUP_ERROR" → lookupError', () {
      expect(
        SettlementPaymentStatus.fromApiString('LOOKUP_ERROR'),
        SettlementPaymentStatus.lookupError,
      );
    });

    test('unrecognized string → unknown (not lookupError)', () {
      expect(
        SettlementPaymentStatus.fromApiString('UNRECOGNIZED'),
        SettlementPaymentStatus.unknown,
      );
    });
  });

  // ── Settlement.isSettled — gates record presentation ──────────────────────

  group('Settlement.isSettled: MONEY_CONTROLS_TRUST = FALSE', () {
    Settlement _settlement(String paymentStatus) => Settlement(
          orderId: 'ord-001',
          paymentStatus: paymentStatus,
        );

    test('FREE → isSettled=true', () {
      expect(_settlement('FREE').isSettled, isTrue);
    });

    test('PAID → isSettled=true', () {
      expect(_settlement('PAID').isSettled, isTrue);
    });

    test('PENDING → isSettled=false', () {
      expect(_settlement('PENDING').isSettled, isFalse);
    });

    test('unrecognized status → isSettled=false', () {
      expect(_settlement('UNKNOWN_STATUS').isSettled, isFalse);
    });
  });

  // ── TrustCurrentness.hasAuthorityUnavailable ──────────────────────────────

  group('TrustCurrentness.hasAuthorityUnavailable', () {
    test('determinationState containing UNAVAILABLE → true', () {
      const t = TrustCurrentness(determinationState: 'AUTHORITY_UNAVAILABLE');
      expect(t.hasAuthorityUnavailable, isTrue);
    });

    test('determinationState "DETERMINED" → false', () {
      const t = TrustCurrentness(determinationState: 'DETERMINED');
      expect(t.hasAuthorityUnavailable, isFalse);
    });

    test('determinationState null → false', () {
      const t = TrustCurrentness();
      expect(t.hasAuthorityUnavailable, isFalse);
    });
  });

  // ── DeterminationResult.fromJson — whyThisTier and whyNotNextTier ─────────

  group('DeterminationResult.fromJson: whyThisTier and whyNotNextTier', () {
    test('whyThisTier as List → joined with space', () {
      final d = DeterminationResult.fromJson({
        'determined_tier': 'T3',
        'why_this_tier': ['Origin established by lab report.', 'Provenance documented.'],
      });
      expect(d.whyThisTier, 'Origin established by lab report. Provenance documented.');
    });

    test('whyThisTier as String → used as-is', () {
      final d = DeterminationResult.fromJson({
        'determined_tier': 'T3',
        'why_this_tier': 'Origin established by lab report.',
      });
      expect(d.whyThisTier, 'Origin established by lab report.');
    });

    test('why_not_higher preferred over why_not_next_tier', () {
      final d = DeterminationResult.fromJson({
        'determined_tier': 'T3',
        'why_not_higher': 'T4 evidence prerequisites not satisfied.',
        'why_not_next_tier': 'Should not appear',
      });
      expect(d.whyNotNextTier, 'T4 evidence prerequisites not satisfied.');
    });

    test('why_not_next_tier used when why_not_higher absent', () {
      final d = DeterminationResult.fromJson({
        'determined_tier': 'T3',
        'why_not_next_tier': 'T4 requirements not met.',
      });
      expect(d.whyNotNextTier, 'T4 requirements not met.');
    });
  });

  // ── SubmissionDetail.fromJson — settlement seam ───────────────────────────

  group('SubmissionDetail.fromJson: settlement seam (hasSettlementSeam)', () {
    Map<String, dynamic> _base() => {
          'submission_id': 'sub-001',
          'status': 'SUBMITTED',
          'asset_name': 'Test Stone',
          'requested_service_tier': 'T3',
          'updated_at': '2026-08-28T10:00:00Z',
          'has_evidence_request': false,
        };

    test('settlement key absent → hasSettlementSeam=false (old API, fail-closed)', () {
      final d = SubmissionDetail.fromJson(_base());
      expect(d.hasSettlementSeam, isFalse);
    });

    test('settlement key present (null value) → hasSettlementSeam=true, settlementData=null', () {
      final json = _base()..['settlement'] = null;
      final d = SubmissionDetail.fromJson(json);
      expect(d.hasSettlementSeam, isTrue);
      expect(d.settlementData, isNull);
    });

    test('settlement key present with Map → hasSettlementSeam=true, settlementData populated', () {
      final json = _base()
        ..['settlement'] = {
          'orderId': 'ord-001',
          'paymentStatus': 'PAID',
        };
      final d = SubmissionDetail.fromJson(json);
      expect(d.hasSettlementSeam, isTrue);
      expect(d.settlementData, isNotNull);
      expect(d.settlementData!.paymentStatus, 'PAID');
    });
  });
}
