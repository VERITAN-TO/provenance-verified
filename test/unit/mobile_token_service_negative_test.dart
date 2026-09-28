// C-owned coverage gap (PR#3 review): MobileTokenService had no dedicated
// unit-level negative-path tests — only backend-dependent integration coverage
// in test/integration/mobile_auth_integration_test.dart. This file adds
// deterministic, backend-independent coverage for failure behavior already
// present in lib/core/auth/mobile_token_service.dart: malformed/absent tenant
// input, bootstrap failure propagation, secure-storage read/write/delete
// failure handling (real FlutterSecureStorage always throws
// MissingPluginException under `package:test`, exercising the same catch(_)
// paths production relies on when storage is unavailable), and refresh/
// concurrency behavior. No backend or platform channel required.

import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provenance_verified_app/core/auth/mobile_token_service.dart';

const _tokenA = 'pvm_live_test_token_a';
const _tokenB = 'pvm_live_test_token_b';
final _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

http.Response _bootstrapOk(String token) => http.Response(
      jsonEncode({
        'token': token,
        'expires_at': '2099-12-31T00:00:00Z',
      }),
      201,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('MobileTokenService — absent/malformed tenant configuration', () {
    test('empty tenantId throws ApiException(TENANT_NOT_CONFIGURED) without calling the backend', () async {
      var callCount = 0;
      final service = MobileTokenService(
        tenantId: '',
        client: MockClient((_) async {
          callCount++;
          return _bootstrapOk(_tokenA);
        }),
      );

      await expectLater(
        service.getToken(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 0)
            .having((e) => e.errorCode, 'errorCode', 'TENANT_NOT_CONFIGURED')),
      );
      expect(callCount, 0, reason: 'must fail closed before any network call');
    });
  });

  group('MobileTokenService — secure-storage failure handling', () {
    // FlutterSecureStorage has no platform channel under `package:test`, so
    // every _storage.read/write/delete call throws MissingPluginException.
    // MobileTokenService wraps all of these in catch(_); these tests assert
    // the documented fail-open/degrade-gracefully behavior, not just that no
    // exception happens to be thrown.
    test('getToken() falls through cache-read failure to bootstrap and still succeeds', () async {
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((_) async => _bootstrapOk(_tokenA)),
      );
      final token = await service.getToken();
      expect(token, _tokenA);
    });

    test('bootstrap request device_id is a valid UUID even though device-id persistence fails', () async {
      Map<String, dynamic>? capturedBody;
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((req) async {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return _bootstrapOk(_tokenA);
        }),
      );
      await service.getToken();
      expect(capturedBody, isNotNull);
      expect(capturedBody!['device_id'], matches(_uuidRe));
    });

    test('forceRefresh() tolerates storage delete failure and re-bootstraps for a new token', () async {
      var call = 0;
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((_) async {
          call++;
          return _bootstrapOk(call == 1 ? _tokenA : _tokenB);
        }),
      );
      final first = await service.getToken();
      expect(first, _tokenA);

      final refreshed = await service.forceRefresh();
      expect(refreshed, _tokenB, reason: 'forceRefresh must clear the in-memory cache and re-bootstrap');
    });
  });

  group('MobileTokenService — bootstrap failure propagation', () {
    test('non-2xx response with structured error body propagates statusCode + errorCode', () async {
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'code': 'TENANT_NOT_AUTHORIZED_FOR_MOBILE', 'message': 'Tenant is not authorized for mobile access.'},
              }),
              403,
              headers: {'content-type': 'application/json'},
            )),
      );

      await expectLater(
        service.getToken(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'TENANT_NOT_AUTHORIZED_FOR_MOBILE')),
      );
    });

    test('non-2xx response with unparseable body falls back to BOOTSTRAP_FAILED', () async {
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((_) async => http.Response('not json', 503)),
      );

      await expectLater(
        service.getToken(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.errorCode, 'errorCode', 'BOOTSTRAP_FAILED')),
      );
    });
  });

  group('MobileTokenService — concurrent bootstrap dedup', () {
    test('overlapping getToken() calls share a single in-flight bootstrap', () async {
      var callCount = 0;
      final service = MobileTokenService(
        tenantId: 'test-tenant',
        client: MockClient((_) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _bootstrapOk(_tokenA);
        }),
      );

      final results = await Future.wait([service.getToken(), service.getToken(), service.getToken()]);
      expect(results, everyElement(_tokenA));
      expect(callCount, 1, reason: 'concurrent callers must dedupe onto one in-flight bootstrap');
    });
  });
}
