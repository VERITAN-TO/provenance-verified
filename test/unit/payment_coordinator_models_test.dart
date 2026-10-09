// Runtime behavioral tests for ClaimantIdentityStatus.fromJson.
// The M4 static-contract suite checks source text; these tests verify actual
// parse behavior at runtime — especially the security-critical verified flag.

import 'package:flutter_test/flutter_test.dart';
import 'package:provenance_verified_app/submit/providers/payment_coordinator.dart';

void main() {
  // ── ClaimantIdentityStatus.fromJson — verified flag ───────────────────────

  group('ClaimantIdentityStatus.fromJson: verified flag', () {
    test('status=VERIFIED → verified=true', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'VERIFIED'});
      expect(s.verified, isTrue);
      expect(s.status, 'VERIFIED');
    });

    test('status=PENDING → verified=false', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'PENDING'});
      expect(s.verified, isFalse);
    });

    test('status=FAILED → verified=false', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'FAILED'});
      expect(s.verified, isFalse);
    });

    test('status=REQUIRES_INPUT → verified=false', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'REQUIRES_INPUT'});
      expect(s.verified, isFalse);
    });

    test('explicit verified=true with non-VERIFIED status → verified=true', () {
      final s = ClaimantIdentityStatus.fromJson({
        'status': 'PENDING',
        'verified': true,
      });
      expect(s.verified, isTrue);
    });

    test('status absent → status=UNKNOWN, verified=false', () {
      final s = ClaimantIdentityStatus.fromJson({});
      expect(s.status, 'UNKNOWN');
      expect(s.verified, isFalse);
    });
  });

  // ── ClaimantIdentityStatus.fromJson — data envelope + fields ─────────────

  group('ClaimantIdentityStatus.fromJson: data envelope and field defaults', () {
    test('payload wrapped under data key parsed correctly', () {
      final s = ClaimantIdentityStatus.fromJson({
        'data': {'status': 'VERIFIED', 'verified': true},
      });
      expect(s.verified, isTrue);
      expect(s.status, 'VERIFIED');
    });

    test('assurance_level absent defaults to GOVERNMENT_ID_MATCHING_SELFIE', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'VERIFIED'});
      expect(s.assuranceLevel, 'GOVERNMENT_ID_MATCHING_SELFIE');
    });

    test('assurance_level present overrides default', () {
      final s = ClaimantIdentityStatus.fromJson({
        'status': 'VERIFIED',
        'assurance_level': 'ENHANCED_DUE_DILIGENCE',
      });
      expect(s.assuranceLevel, 'ENHANCED_DUE_DILIGENCE');
    });

    test('verified_at parsed as DateTime when present', () {
      final s = ClaimantIdentityStatus.fromJson({
        'status': 'VERIFIED',
        'verified_at': '2026-08-28T10:00:00Z',
      });
      expect(s.verifiedAt, isNotNull);
      expect(s.verifiedAt!.year, 2026);
    });

    test('verified_at absent → verifiedAt=null', () {
      final s = ClaimantIdentityStatus.fromJson({'status': 'VERIFIED'});
      expect(s.verifiedAt, isNull);
    });
  });
}
