// Runtime behavioral tests for actionability_models.dart and receipt_models.dart.
// Focus: fail-closed security properties not covered by the machine-trust suite.

import 'package:test/test.dart';
import 'package:provenance_verified_app/actionability/actionability_models.dart';
import 'package:provenance_verified_app/reliance/receipt_models.dart';

void main() {
  // ── ActionabilityDecision.fromJson — fail-closed ──────────────────────────

  group('ActionabilityDecision.fromJson: fail-closed security property', () {
    test('"ALLOW" → allow', () {
      expect(ActionabilityDecision.fromJson('ALLOW'), ActionabilityDecision.allow);
    });

    test('"DENY" → deny', () {
      expect(ActionabilityDecision.fromJson('DENY'), ActionabilityDecision.deny);
    });

    test('"QUALIFY" → qualify', () {
      expect(ActionabilityDecision.fromJson('QUALIFY'), ActionabilityDecision.qualify);
    });

    test('null → unknown (fail-closed)', () {
      expect(ActionabilityDecision.fromJson(null), ActionabilityDecision.unknown);
    });

    test('unrecognized string → unknown (fail-closed, not allow)', () {
      expect(
        ActionabilityDecision.fromJson('SUSPICIOUS_ALLOW_OVERRIDE'),
        ActionabilityDecision.unknown,
      );
    });

    test('empty string → unknown (fail-closed)', () {
      expect(ActionabilityDecision.fromJson(''), ActionabilityDecision.unknown);
    });
  });

  // ── ActionabilityPurpose.fromJson ─────────────────────────────────────────

  group('ActionabilityPurpose.fromJson', () {
    test('"PURCHASE" → purchase', () {
      expect(ActionabilityPurpose.fromJson('PURCHASE'), ActionabilityPurpose.purchase);
    });

    test('"PUBLIC_MARKETING_CLAIM" → publicMarketingClaim', () {
      expect(
        ActionabilityPurpose.fromJson('PUBLIC_MARKETING_CLAIM'),
        ActionabilityPurpose.publicMarketingClaim,
      );
    });

    test('null → custom', () {
      expect(ActionabilityPurpose.fromJson(null), ActionabilityPurpose.custom);
    });

    test('unrecognized string → custom', () {
      expect(
        ActionabilityPurpose.fromJson('UNKNOWN_PURPOSE'),
        ActionabilityPurpose.custom,
      );
    });
  });

  // ── ActionabilityResult.fromJson ──────────────────────────────────────────

  group('ActionabilityResult.fromJson', () {
    test('decision parsed from JSON correctly', () {
      final r = ActionabilityResult.fromJson({
        'decision': 'ALLOW',
        'reason_codes': ['TIER_SUFFICIENT'],
        'trust_state_digest': 'sha256:abc123',
        'as_of': '2026-08-28T10:00:00Z',
      });
      expect(r.decision, ActionabilityDecision.allow);
      expect(r.reasonCodes, ['TIER_SUFFICIENT']);
    });

    test('trust_state_digest extracted from JSON key', () {
      const digest = 'sha256:deadbeef0000000000000000000000000000000000000000000000000000abcd';
      final r = ActionabilityResult.fromJson({
        'decision': 'DENY',
        'trust_state_digest': digest,
        'as_of': '2026-08-28T10:00:00Z',
      });
      expect(r.trustStateDigest, digest);
    });

    test('unrecognized decision in JSON → unknown (fail-closed)', () {
      final r = ActionabilityResult.fromJson({
        'decision': 'SOMETHING_NEW',
        'as_of': '2026-08-28T10:00:00Z',
      });
      expect(r.decision, ActionabilityDecision.unknown);
    });
  });

  // ── RelianceReceipt._parseValidity (via fromJson) ─────────────────────────

  group('RelianceReceipt fromJson: validity_state parsing', () {
    RelianceReceipt _receiptFromValidity(dynamic validityState) => RelianceReceipt.fromJson({
          'receipt_id': 'RR-V1-test-001',
          'public_id': 'PV-QUAL-001',
          'physical_subject_id': 'phys-001',
          'trust_state_digest': 'sha256:aabbcc',
          'purpose': 'PURCHASE',
          'decision': 'ALLOW',
          'created_at': '2026-08-28T10:00:00.000Z',
          if (validityState != null) 'validity_state': validityState,
        });

    test('"VALID" → ReceiptValidityState.valid', () {
      expect(_receiptFromValidity('VALID').validityState, ReceiptValidityState.valid);
    });

    test('"INVALIDATED" → ReceiptValidityState.invalidated', () {
      expect(
        _receiptFromValidity('INVALIDATED').validityState,
        ReceiptValidityState.invalidated,
      );
    });

    test('"EXPIRED" → ReceiptValidityState.expired', () {
      expect(
        _receiptFromValidity('EXPIRED').validityState,
        ReceiptValidityState.expired,
      );
    });

    test('null validity_state → ReceiptValidityState.unknown', () {
      expect(_receiptFromValidity(null).validityState, ReceiptValidityState.unknown);
    });

    test('unrecognized validity_state → ReceiptValidityState.unknown', () {
      expect(
        _receiptFromValidity('UNRECOGNIZED_STATE').validityState,
        ReceiptValidityState.unknown,
      );
    });

    test('is_server_issued=true parsed correctly', () {
      final r = RelianceReceipt.fromJson({
        'receipt_id': 'RR-V1-server-001',
        'public_id': 'PV-QUAL-001',
        'physical_subject_id': 'phys-001',
        'trust_state_digest': 'sha256:aabbcc',
        'purpose': 'PURCHASE',
        'decision': 'ALLOW',
        'created_at': '2026-08-28T10:00:00.000Z',
        'is_server_issued': true,
      });
      expect(r.isServerIssued, isTrue);
    });
  });
}
