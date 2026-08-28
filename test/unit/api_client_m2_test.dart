// M2: API client real endpoint tests with mocked HTTP.
// Tests the actual request construction, auth headers, and response parsing.
// M2-11: getMachineTrust sends Bearer token auth.
// M2-12: getMachineTrust calls correct endpoint.
// M2-13: trust_state_digest extracted from x-pv-trust-state-digest header.
// M2-14: physical_subject_id extracted from x-pv-physical-subject header.
// M2-15: 401 → ApiException with INVALID_API_KEY code.
// M2-16: 403 → ApiException with INSUFFICIENT_SCOPE.
// M2-17: 429 → ApiException with RATE_LIMIT_EXCEEDED.
// M2-18: Evaluateactionability sends correct request body.
// M2-19: createRelianceReceipt sends correct request.

import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provenance_verified_app/core/network/api_client.dart';

const _baseUrl = 'https://provenance-verified-private.vercel.app';
const _apiKey = 'pv_live_test_key_for_qual_only';
const _trustStateDigest = 'sha256:aaaa0000000000000000000000000000000000000000000000000000deadbeef';
const _physicalSubject = 'phys-qual-001';

Map<String, dynamic> _machineTrustPayload({bool eligible = true, int tier = 3}) => {
  'schema': 'pv.machine-trust.v1',
  'subject': {'subject_id': 'PV-QUAL-001', 'subject_type': 'gem', 'identity_state': 'RESOLVED'},
  'claims': [
    {'claim_id': 'c-origin', 'predicate': 'geographic_origin', 'state': 'SUPPORTED'},
  ],
  'policy': {'policy_id': 'pol-v1', 'policy_version': 'PV-POLICY-2026.08-V4-R1', 'policy_digest': 'sha256:pol'},
  'determination': {
    'determination_id': 'det-m2-001',
    'tier': tier,
    'tier_label': 'T$tier',
    'current': true,
    'determination_digest': 'sha256:det001',
    'eligible': eligible,
    'material_conflict': false,
  },
  'limitations': [],
  'allowed_claims': [],
  'prohibited_inferences': [],
  'freshness': {'state': 'CURRENT', 'as_of': '2026-08-28T10:00:00Z'},
  'authority': {'determination_authoritative': true, 'issuance_authorized': true},
  'integrity': {'evidence_manifest_valid': true, 'determination_digest_valid': true, 'credential_signature_valid': true},
  'credential': {'credential_id': 'cred-001', 'status': 'ACTIVE', 'authoritative': true},
  'continuity': {'state': 'PARTIAL'},
  'lifecycle': {'state': 'ACTIVE'},
  'as_of': '2026-08-28T10:00:00Z',
  'served_at': '2026-08-28T10:00:01Z',
};

void main() {
  // ── M2-11: Bearer auth header ─────────────────────────────────────────────

  group('M2-11: getMachineTrust sends Authorization: Bearer', () {
    test('Bearer token sent in request', () async {
      String? capturedAuth;
      final mockClient = MockClient((req) async {
        capturedAuth = req.headers['authorization'];
        return http.Response(
          jsonEncode(_machineTrustPayload()),
          200,
          headers: {
            'content-type': 'application/json',
            'x-pv-trust-state-digest': _trustStateDigest,
            'x-pv-physical-subject': _physicalSubject,
          },
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: _baseUrl,
        apiKey: _apiKey,
      );
      await client.getMachineTrust('PV-QUAL-001');
      expect(capturedAuth, 'Bearer $_apiKey');
    });

    test('no Authorization header when apiKey empty', () async {
      String? capturedAuth;
      final mockClient = MockClient((req) async {
        capturedAuth = req.headers['authorization'];
        return http.Response(
          jsonEncode(_machineTrustPayload()),
          200,
          headers: {
            'content-type': 'application/json',
            'x-pv-trust-state-digest': _trustStateDigest,
            'x-pv-physical-subject': _physicalSubject,
          },
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: '');
      await client.getMachineTrust('PV-QUAL-001');
      expect(capturedAuth, null);
    });
  });

  // ── M2-12: Correct endpoint URL ───────────────────────────────────────────

  group('M2-12: getMachineTrust calls correct endpoint', () {
    test('GET /api/v1/trust/{publicId}/machine', () async {
      Uri? capturedUri;
      final mockClient = MockClient((req) async {
        capturedUri = req.url;
        return http.Response(
          jsonEncode(_machineTrustPayload()),
          200,
          headers: {
            'content-type': 'application/json',
            'x-pv-trust-state-digest': _trustStateDigest,
            'x-pv-physical-subject': _physicalSubject,
          },
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      await client.getMachineTrust('PV-QUAL-001');
      expect(capturedUri?.path, '/api/v1/trust/PV-QUAL-001/machine');
    });

    test('publicId URL-encoded in path', () async {
      Uri? capturedUri;
      final mockClient = MockClient((req) async {
        capturedUri = req.url;
        return http.Response(
          jsonEncode(_machineTrustPayload()),
          200,
          headers: {
            'content-type': 'application/json',
            'x-pv-trust-state-digest': _trustStateDigest,
            'x-pv-physical-subject': _physicalSubject,
          },
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      await client.getMachineTrust('PV-QUAL-A/B');
      expect(capturedUri?.toString(), contains('/api/v1/trust/PV-QUAL-A%2FB/machine'));
    });

    test('uses GET method', () async {
      String? capturedMethod;
      final mockClient = MockClient((req) async {
        capturedMethod = req.method;
        return http.Response(
          jsonEncode(_machineTrustPayload()),
          200,
          headers: {
            'content-type': 'application/json',
            'x-pv-trust-state-digest': _trustStateDigest,
            'x-pv-physical-subject': _physicalSubject,
          },
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      await client.getMachineTrust('PV-QUAL-001');
      expect(capturedMethod, 'GET');
    });
  });

  // ── M2-13: trust_state_digest from header ─────────────────────────────────

  group('M2-13: trust_state_digest extracted from response header', () {
    test('digest from x-pv-trust-state-digest header', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode(_machineTrustPayload()),
            200,
            headers: {
              'content-type': 'application/json',
              'x-pv-trust-state-digest': _trustStateDigest,
              'x-pv-physical-subject': _physicalSubject,
            },
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      final r = await client.getMachineTrust('PV-QUAL-001');
      expect(r.trustStateDigest, _trustStateDigest);
    });
  });

  // ── M2-14: physical_subject_id from header ────────────────────────────────

  group('M2-14: physical_subject_id extracted from response header', () {
    test('physicalSubjectId from x-pv-physical-subject header', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode(_machineTrustPayload()),
            200,
            headers: {
              'content-type': 'application/json',
              'x-pv-trust-state-digest': _trustStateDigest,
              'x-pv-physical-subject': _physicalSubject,
            },
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      final r = await client.getMachineTrust('PV-QUAL-001');
      expect(r.physicalSubjectId, _physicalSubject);
    });
  });

  // ── M2-15: 401 → ApiException ─────────────────────────────────────────────

  group('M2-15: 401 → ApiException (fail-closed)', () {
    test('401 INVALID_API_KEY throws ApiException', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'schema': 'pv.machine-trust.v1',
              'error': {'code': 'INVALID_API_KEY', 'message': 'API key not found.'},
            }),
            401,
            headers: {'content-type': 'application/json'},
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: 'bad_key');
      expect(() => client.getMachineTrust('PV-QUAL-001'), throwsA(isA<ApiException>()));
    });

    test('401 exception has correct statusCode', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'schema': 'pv.machine-trust.v1',
              'error': {'code': 'INVALID_API_KEY'},
            }),
            401,
            headers: {'content-type': 'application/json'},
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: 'bad_key');
      try {
        await client.getMachineTrust('PV-QUAL-001');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
    });
  });

  // ── M2-16: 403 → ApiException(INSUFFICIENT_SCOPE) ────────────────────────

  group('M2-16: 403 INSUFFICIENT_SCOPE → ApiException', () {
    test('403 → ApiException with errorCode', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'schema': 'pv.machine-trust.v1',
              'error': {'code': 'INSUFFICIENT_SCOPE', 'message': 'Requires trust:read scope.'},
            }),
            403,
            headers: {'content-type': 'application/json'},
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      try {
        await client.getMachineTrust('PV-QUAL-001');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.errorCode, 'INSUFFICIENT_SCOPE');
      }
    });
  });

  // ── M2-17: 429 → ApiException(RATE_LIMIT_EXCEEDED) ───────────────────────

  group('M2-17: 429 RATE_LIMIT_EXCEEDED → ApiException', () {
    test('429 throws ApiException', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'schema': 'pv.machine-trust.v1',
              'error': {'code': 'RATE_LIMIT_EXCEEDED'},
            }),
            429,
            headers: {'content-type': 'application/json'},
          ));
      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      try {
        await client.getMachineTrust('PV-QUAL-001');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.errorCode, 'RATE_LIMIT_EXCEEDED');
      }
    });
  });

  // ── M2-18: evaluateActionability request body ─────────────────────────────

  group('M2-18: evaluateActionability sends correct request', () {
    test('POST /api/v1/actionability', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((req) async {
        capturedUri = req.url;
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'schema': 'pv.machine-actionability.v1',
            'decision': 'ALLOW',
            'reason_codes': [],
            'trust_state_digest': _trustStateDigest,
            'as_of': '2026-08-28T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      final result = await client.evaluateActionability(
        subjectId: 'PV-QUAL-001',
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
      );

      expect(capturedUri?.path, '/api/v1/actionability');
      expect(capturedBody?['subject_id'], 'PV-QUAL-001');
      expect(capturedBody?['purpose_id'], 'PURCHASE');
      expect(result['decision'], 'ALLOW');
    });
  });

  // ── M2-19: createRelianceReceipt request ─────────────────────────────────

  group('M2-19: createRelianceReceipt sends correct request', () {
    test('POST /api/v1/reliance-receipts', () async {
      Uri? capturedUri;
      final mockClient = MockClient((req) async {
        capturedUri = req.url;
        return http.Response(
          jsonEncode({
            'schema': 'pv.machine-actionability.v1',
            'decision': 'ALLOW',
            'receipt_id': 'RR-V1-server-001',
            'trust_state_digest': _trustStateDigest,
            'reason_codes': [],
            'as_of': '2026-08-28T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      final result = await client.createRelianceReceipt(
        subjectId: 'PV-QUAL-001',
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
      );

      expect(capturedUri?.path, '/api/v1/reliance-receipts');
      expect(result['receipt_id'], 'RR-V1-server-001');
      expect(result['decision'], 'ALLOW');
    });

    test('server receipt has trust_state_digest', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'schema': 'pv.machine-actionability.v1',
              'decision': 'ALLOW',
              'receipt_id': 'RR-V1-server-002',
              'trust_state_digest': _trustStateDigest,
              'reason_codes': [],
              'as_of': '2026-08-28T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final client = ApiClient(client: mockClient, baseUrl: _baseUrl, apiKey: _apiKey);
      final result = await client.createRelianceReceipt(
        subjectId: 'PV-QUAL-001',
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
      );
      expect(result['trust_state_digest'], _trustStateDigest);
    });
  });
}
