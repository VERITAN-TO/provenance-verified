// Runtime behavioral tests for auth_models.dart, home_models.dart, and my_pv_models.dart.
// Focus: CustomerSession timing properties, AlertType fail-closed parsing,
// and null-trust-tier semantics (CUSTOMER_SELECTS_TIER=FALSE; never overclaim tier).

import 'package:test/test.dart';
import 'package:provenance_verified_app/auth/auth_models.dart';
import 'package:provenance_verified_app/home/models/home_models.dart';
import 'package:provenance_verified_app/my_pv/models/my_pv_models.dart';

void main() {
  // ── CustomerSession.isExpired ─────────────────────────────────────────────

  group('CustomerSession.isExpired', () {
    test('past expiresAt → isExpired=true', () {
      final s = CustomerSession(
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        userId: 'u1',
        displayName: 'Test User',
      );
      expect(s.isExpired, isTrue);
    });

    test('future expiresAt → isExpired=false', () {
      final s = CustomerSession(
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        userId: 'u1',
        displayName: 'Test User',
      );
      expect(s.isExpired, isFalse);
    });
  });

  // ── CustomerSession.expiresWithin ─────────────────────────────────────────

  group('CustomerSession.expiresWithin', () {
    test('expiresAt within threshold → expiresWithin=true', () {
      final s = CustomerSession(
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
        userId: 'u1',
        displayName: 'Test User',
      );
      expect(s.expiresWithin(const Duration(minutes: 5)), isTrue);
    });

    test('expiresAt beyond threshold → expiresWithin=false', () {
      final s = CustomerSession(
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
        userId: 'u1',
        displayName: 'Test User',
      );
      expect(s.expiresWithin(const Duration(minutes: 5)), isFalse);
    });
  });

  // ── CustomerSession.fromJson / toJson round-trip ──────────────────────────

  group('CustomerSession.fromJson / toJson', () {
    test('round-trip preserves all fields', () {
      final original = CustomerSession(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
        expiresAt: DateTime.utc(2026, 12, 31, 23, 59, 59),
        userId: 'user-001',
        displayName: 'Alice',
      );
      final restored = CustomerSession.fromJson(original.toJson());
      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.userId, original.userId);
      expect(restored.displayName, original.displayName);
    });

    test('copyWith only replaces specified field', () {
      final original = CustomerSession(
        accessToken: 'orig-access',
        refreshToken: 'orig-refresh',
        expiresAt: DateTime.utc(2026, 1, 1),
        userId: 'u1',
        displayName: 'Alice',
      );
      final updated = original.copyWith(accessToken: 'new-access');
      expect(updated.accessToken, 'new-access');
      expect(updated.refreshToken, original.refreshToken);
      expect(updated.userId, original.userId);
    });
  });

  // ── AlertType.fromJson — fail-closed ──────────────────────────────────────

  group('AlertType.fromJson: fail-closed', () {
    test('"TRUST_STATE_CHANGE" → trustStateChange', () {
      expect(AlertType.fromJson('TRUST_STATE_CHANGE'), AlertType.trustStateChange);
    });

    test('"STALE_RECEIPT" → staleReceipt', () {
      expect(AlertType.fromJson('STALE_RECEIPT'), AlertType.staleReceipt);
    });

    test('"CERTIFICATION_EXPIRING" → certificationExpiring', () {
      expect(AlertType.fromJson('CERTIFICATION_EXPIRING'), AlertType.certificationExpiring);
    });

    test('"SUBMISSION_REQUIRES_ACTION" → submissionRequiresAction', () {
      expect(
        AlertType.fromJson('SUBMISSION_REQUIRES_ACTION'),
        AlertType.submissionRequiresAction,
      );
    });

    test('null → unknown (fail-closed, not a grant)', () {
      expect(AlertType.fromJson(null), AlertType.unknown);
    });

    test('unrecognized string → unknown (fail-closed)', () {
      expect(AlertType.fromJson('SUSPICIOUS_GRANT'), AlertType.unknown);
    });
  });

  // ── RecentScan.fromJson — null-trust-tier (never overclaim) ──────────────

  group('RecentScan.fromJson: trust_tier null-safety', () {
    test('trust_tier absent → trustTier=null (no overclaim)', () {
      final r = RecentScan.fromJson({
        'public_id': 'PV-001',
        'eligible': true,
        'scanned_at': '2026-08-28T10:00:00Z',
      });
      expect(r.trustTier, isNull);
    });

    test('eligible absent → eligible=false (fail-closed)', () {
      final r = RecentScan.fromJson({
        'public_id': 'PV-001',
        'scanned_at': '2026-08-28T10:00:00Z',
      });
      expect(r.eligible, isFalse);
    });

    test('trust_tier present → parsed as int', () {
      final r = RecentScan.fromJson({
        'public_id': 'PV-001',
        'trust_tier': 3,
        'eligible': true,
        'scanned_at': '2026-08-28T10:00:00Z',
      });
      expect(r.trustTier, 3);
    });
  });

  // ── SubmissionSummary.fromJson — field defaults ───────────────────────────

  group('SubmissionSummary.fromJson: field defaults', () {
    test('status absent → "unknown"', () {
      final s = SubmissionSummary.fromJson({
        'submission_id': 'sub-001',
        'asset_name': 'Test Stone',
        'updated_at': '2026-08-28T10:00:00Z',
      });
      expect(s.status, 'unknown');
    });

    test('asset_name absent → "Unnamed asset"', () {
      final s = SubmissionSummary.fromJson({
        'submission_id': 'sub-001',
        'status': 'SUBMITTED',
        'updated_at': '2026-08-28T10:00:00Z',
      });
      expect(s.assetName, 'Unnamed asset');
    });
  });

  // ── TrustAlert.fromJson — read defaults ───────────────────────────────────

  group('TrustAlert.fromJson: read field default', () {
    test('read absent → read=false', () {
      final a = TrustAlert.fromJson({
        'alert_id': 'al-001',
        'asset_name': 'Test Stone',
        'alert_type': 'TRUST_STATE_CHANGE',
        'message': 'Trust state changed.',
        'created_at': '2026-08-28T10:00:00Z',
      });
      expect(a.read, isFalse);
    });
  });

  // ── CustomerAsset.fromJson — null-trust-tier (never overclaim) ────────────

  group('CustomerAsset.fromJson: trust_tier null-safety and defaults', () {
    test('trust_tier absent → trustTier=null (no overclaim)', () {
      final a = CustomerAsset.fromJson({
        'asset_id': 'asset-001',
        'public_id': 'PV-001',
        'asset_name': 'Test Stone',
        'asset_type': 'DIAMOND',
        'eligible': false,
      });
      expect(a.trustTier, isNull);
    });

    test('eligible absent → eligible=false (fail-closed)', () {
      final a = CustomerAsset.fromJson({
        'asset_id': 'asset-001',
        'public_id': 'PV-001',
        'asset_name': 'Test Stone',
        'asset_type': 'DIAMOND',
      });
      expect(a.eligible, isFalse);
    });

    test('hasStaledReceipts absent → hasStaledReceipts=false', () {
      final a = CustomerAsset.fromJson({
        'asset_id': 'asset-001',
        'public_id': 'PV-001',
        'asset_name': 'Test Stone',
        'asset_type': 'DIAMOND',
        'eligible': true,
      });
      expect(a.hasStaledReceipts, isFalse);
    });

    test('lastVerifiedAt absent → lastVerifiedAt=null', () {
      final a = CustomerAsset.fromJson({
        'asset_id': 'asset-001',
        'public_id': 'PV-001',
        'asset_name': 'Test Stone',
        'asset_type': 'DIAMOND',
        'eligible': false,
      });
      expect(a.lastVerifiedAt, isNull);
    });
  });
}
