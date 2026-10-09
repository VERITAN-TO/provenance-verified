// Runtime behavioral tests for core/config/constants.dart and offline/offline_state.dart.
// Critical: actionabilityCacheForReliance=false is an M1 Security Law.
// publicIdPattern and digestPattern are security-boundary validators.

import 'package:test/test.dart';
import 'package:provenance_verified_app/core/config/constants.dart';
import 'package:provenance_verified_app/offline/offline_state.dart';

void main() {
  // ── PvConstants.actionabilityCacheForReliance — M1 Security Law ──────────

  group('PvConstants: M1 Security Law', () {
    test('actionabilityCacheForReliance is definitively false', () {
      // M1 Security Law: actionability must never be cached for reliance.
      // This test locks the invariant at runtime.
      expect(PvConstants.actionabilityCacheForReliance, isFalse);
    });
  });

  // ── PvConstants.publicIdPattern ───────────────────────────────────────────

  group('PvConstants.publicIdPattern', () {
    test('valid PV-XXXX-XXXX matches', () {
      expect(PvConstants.publicIdPattern.hasMatch('PV-QUAL-001'), isTrue);
    });

    test('valid DET-V1-XXXX-XXXX matches', () {
      expect(PvConstants.publicIdPattern.hasMatch('DET-V1-ABC123-XYZ'), isTrue);
    });

    test('valid DET-XXXX-XXXX matches', () {
      expect(PvConstants.publicIdPattern.hasMatch('DET-ABC-001'), isTrue);
    });

    test('bare string without prefix does not match', () {
      expect(PvConstants.publicIdPattern.hasMatch('ACTIVE'), isFalse);
    });

    test('empty string does not match', () {
      expect(PvConstants.publicIdPattern.hasMatch(''), isFalse);
    });

    test('only prefix without segments does not match', () {
      expect(PvConstants.publicIdPattern.hasMatch('PV-'), isFalse);
    });
  });

  // ── PvConstants.digestPattern ─────────────────────────────────────────────

  group('PvConstants.digestPattern', () {
    test('valid sha256 digest (64 hex chars) matches', () {
      const digest = 'sha256:deadbeef0000000000000000000000000000000000000000000000000000abcd';
      expect(PvConstants.digestPattern.hasMatch(digest), isTrue);
    });

    test('truncated hash does not match', () {
      const digest = 'sha256:deadbeef';
      expect(PvConstants.digestPattern.hasMatch(digest), isFalse);
    });

    test('wrong prefix does not match', () {
      const digest = 'md5:deadbeef0000000000000000000000000000000000000000000000000000abcd';
      expect(PvConstants.digestPattern.hasMatch(digest), isFalse);
    });

    test('uppercase hex does not match (pattern requires lowercase)', () {
      const digest = 'sha256:DEADBEEF0000000000000000000000000000000000000000000000000000ABCD';
      expect(PvConstants.digestPattern.hasMatch(digest), isFalse);
    });
  });

  // ── CachedRecord default state ────────────────────────────────────────────

  group('CachedRecord: default state', () {
    test('default state is CacheState.fresh', () {
      final r = CachedRecord(
        publicId: 'PV-001',
        data: {},
        cachedAt: DateTime.now().toUtc(),
      );
      expect(r.state, CacheState.fresh);
    });

    test('explicit stale state preserved', () {
      final r = CachedRecord(
        publicId: 'PV-001',
        data: {},
        cachedAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        state: CacheState.stale,
      );
      expect(r.state, CacheState.stale);
    });
  });
}
