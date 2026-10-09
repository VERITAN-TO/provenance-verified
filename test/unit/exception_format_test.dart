// Runtime behavioral tests for AuthException and ApiException toString formats.
// These lock the error-reporting contract so log/display consumers don't break silently.

import 'package:test/test.dart';
import 'package:provenance_verified_app/auth/services/auth_service.dart';
import 'package:provenance_verified_app/core/auth/mobile_token_service.dart';

void main() {
  // ── AuthException.toString ────────────────────────────────────────────────

  group('AuthException: constructor and toString', () {
    test('toString with errorCode includes /errorCode segment', () {
      const e = AuthException(401, 'Unauthorised.', errorCode: 'UNAUTHORIZED');
      expect(e.toString(), 'AuthException(401/UNAUTHORIZED): Unauthorised.');
    });

    test('toString without errorCode omits /errorCode segment', () {
      const e = AuthException(500, 'Server error.');
      expect(e.toString(), 'AuthException(500): Server error.');
    });

    test('statusCode and message are preserved on construction', () {
      const e = AuthException(403, 'Forbidden.', errorCode: 'FORBIDDEN');
      expect(e.statusCode, 403);
      expect(e.message, 'Forbidden.');
      expect(e.errorCode, 'FORBIDDEN');
    });

    test('is an Exception', () {
      const e = AuthException(0, 'err');
      expect(e, isA<Exception>());
    });
  });

  // ── ApiException.toString ─────────────────────────────────────────────────

  group('ApiException: constructor and toString', () {
    test('toString with errorCode shows errorCode', () {
      const e = ApiException(404, 'Not found.', errorCode: 'NOT_FOUND');
      expect(e.toString(), 'ApiException(404/NOT_FOUND): Not found.');
    });

    test('toString without errorCode shows empty string after /', () {
      const e = ApiException(503, 'Unavailable.');
      expect(e.toString(), 'ApiException(503/): Unavailable.');
    });

    test('statusCode and message are preserved on construction', () {
      const e = ApiException(200, 'hasError.', errorCode: 'TRUST_RECORD_INVALID');
      expect(e.statusCode, 200);
      expect(e.message, 'hasError.');
      expect(e.errorCode, 'TRUST_RECORD_INVALID');
    });

    test('is an Exception', () {
      const e = ApiException(0, 'err');
      expect(e, isA<Exception>());
    });
  });
}
