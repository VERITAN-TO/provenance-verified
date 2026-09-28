// C-owned coverage gap (PR#3 review, same sweep as mobile_token_service_negative_test.dart):
// AuthService (customer verified-human session: sign-in/refresh/sign-out) had
// zero existing tests of any kind. This file adds deterministic,
// backend-independent coverage for the fail-closed paths already present in
// lib/auth/services/auth_service.dart: no-session refresh, and sign-out with
// no stored session. Real FlutterSecureStorage has no platform channel under
// `package:test`, so _storage.read always throws MissingPluginException;
// getStoredSession() catches this and returns null, which is exactly the
// "no session" state these tests exercise. No backend or platform channel
// required.

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provenance_verified_app/auth/services/auth_service.dart';

void main() {
  group('AuthService — no stored session (secure-storage unavailable)', () {
    test('getStoredSession() returns null when storage is unavailable, without calling the backend', () async {
      var callCount = 0;
      final service = AuthService(
        client: MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        }),
      );
      final session = await service.getStoredSession();
      expect(session, isNull);
      expect(callCount, 0, reason: 'must not call the network to resolve a session that cannot be read');
    });

    test('refreshSession() fails closed with AuthException(NO_SESSION) when there is nothing to refresh', () async {
      var callCount = 0;
      final service = AuthService(
        client: MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.refreshSession(),
        throwsA(isA<AuthException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.errorCode, 'errorCode', 'NO_SESSION')),
      );
      expect(callCount, 0, reason: 'must fail closed before any network call');
    });

    test('signOut() completes without throwing when there is no stored session, without calling the backend', () async {
      var callCount = 0;
      final service = AuthService(
        client: MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        }),
      );

      await service.signOut();
      expect(callCount, 0, reason: 'sign-out with no session must not attempt a network call');
    });
  });
}
