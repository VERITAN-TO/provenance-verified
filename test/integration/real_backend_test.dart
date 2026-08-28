// M2: Real backend integration tests.
// These tests call the LIVE PV backend. They SKIP when PV_API_KEY is not set.
// Run with: flutter test --dart-define=PV_API_KEY=<key> --dart-define=PV_TENANT_ID=<tenant>
//            --dart-define=PV_QUAL_SUBJECT_ID=<real_public_id>
//
// Gates covered:
//   M2-INT-01: Trust query → real MachineTrustResponse
//   M2-INT-02: trust_state_digest from real response header
//   M2-INT-03: moneyControlsTrust = false in real response
//   M2-INT-04: UNQUALIFIED_T1_OVERCLAIM = ZERO (real backend)
//   M2-INT-05: Actionability evaluate → real decision
//   M2-INT-06: Reliance receipt → server-issued receipt
//   M2-INT-07: Digest change detection (stale receipt invalidation)
//   M2-INT-08: Freshness state is CURRENT or known state

// ignore_for_file: avoid_print
import 'package:test/test.dart';
import 'package:provenance_verified_app/core/config/environment.dart';
import 'package:provenance_verified_app/core/network/api_client.dart';
import 'package:provenance_verified_app/reliance/receipt_models.dart';
import 'package:provenance_verified_app/actionability/actionability_models.dart';

// Qualification test subject — must be a real registered asset in the qual backend.
// Defaults to a deterministic qual fixture ID; override via --dart-define.
const _qualSubjectId = String.fromEnvironment(
  'PV_QUAL_SUBJECT_ID',
  defaultValue: 'PV-TEST-S1-001',
);

void main() {
  // Skip all integration tests when credentials are not configured.
  if (!Env.hasQualCredentials) {
    print('SKIP: PV_API_KEY or PV_TENANT_ID not set — skipping real backend tests.');
    print('Run with: flutter test --dart-define=PV_API_KEY=<key> --dart-define=PV_TENANT_ID=<id>');
    return;
  }

  late ApiClient client;

  setUpAll(() {
    client = ApiClient(
      baseUrl: Env.pvApiBaseUrl,
      apiKey: Env.pvApiKey,
    );
  });

  tearDownAll(() => client.dispose());

  // ── M2-INT-01: Real trust query ───────────────────────────────────────────

  group('M2-INT-01: Real trust query (GET /api/v1/trust/{id}/machine)', () {
    test('returns pv.machine-trust.v1 schema', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.schema, 'pv.machine-trust.v1');
      expect(r.hasError, false);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('subjectId is non-empty', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.subjectId, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('determinationId is non-empty', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.determinationId, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('tier is 1, 2, 3, or 4', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.tier, inInclusiveRange(1, 4));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('toTrustRecord produces valid TrustRecord', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      final tr = r.toTrustRecord(_qualSubjectId);
      expect(tr.publicId, _qualSubjectId);
      expect(tr.trustStateDigest, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-02: trust_state_digest from real header ────────────────────────

  group('M2-INT-02: trust_state_digest from real response header', () {
    test('digest is non-empty', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.trustStateDigest, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('digest starts with sha256:', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      expect(r.trustStateDigest, startsWith('sha256:'));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-03: moneyControlsTrust = false ─────────────────────────────────

  group('M2-INT-03: moneyControlsTrust = false (MTA1 real backend)', () {
    test('moneyControlsTrust always false in real TrustRecord', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      final tr = r.toTrustRecord(_qualSubjectId);
      expect(tr.moneyControlsTrust, false);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-04: UNQUALIFIED_T1_OVERCLAIM = ZERO ────────────────────────────

  group('M2-INT-04: UNQUALIFIED_T1_OVERCLAIM = ZERO (real backend)', () {
    test('eligible=false → safeTier=null', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      final tr = r.toTrustRecord(_qualSubjectId);
      if (!tr.isQualified) {
        expect(tr.safeTier, null);
      } else {
        expect(tr.safeTier, isNotNull);
        expect(tr.safeTier, inInclusiveRange(1, 4));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-05: Real actionability ─────────────────────────────────────────

  group('M2-INT-05: Real actionability evaluation', () {
    test('POST /api/v1/actionability returns known decision', () async {
      final json = await client.evaluateActionability(
        subjectId: _qualSubjectId,
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
        principal: 'pv-mobile-qual',
        organization: 'pv-mobile-qual',
      );
      final result = ActionabilityResult.fromJson(json);
      // Decision must be ALLOW, QUALIFY, DENY, or UNKNOWN — never arbitrary value.
      expect(
        [
          ActionabilityDecision.allow,
          ActionabilityDecision.qualify,
          ActionabilityDecision.deny,
          ActionabilityDecision.unknown,
        ],
        contains(result.decision),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('actionability has trust_state_digest', () async {
      final json = await client.evaluateActionability(
        subjectId: _qualSubjectId,
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
        principal: 'pv-mobile-qual',
        organization: 'pv-mobile-qual',
      );
      final result = ActionabilityResult.fromJson(json);
      expect(result.trustStateDigest, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-06: Real reliance receipt ──────────────────────────────────────

  group('M2-INT-06: Real reliance receipt creation', () {
    test('POST /api/v1/reliance-receipts returns receipt', () async {
      final json = await client.createRelianceReceipt(
        subjectId: _qualSubjectId,
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
      );
      final decision = ActionabilityDecision.fromJson(json['decision']);
      expect(
        [
          ActionabilityDecision.allow,
          ActionabilityDecision.qualify,
          ActionabilityDecision.deny,
          ActionabilityDecision.unknown,
        ],
        contains(decision),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('server receipt has receipt_id', () async {
      final json = await client.createRelianceReceipt(
        subjectId: _qualSubjectId,
        purposeId: 'PURCHASE',
        requestedAction: 'evaluate',
        claimScope: 'standard',
      );
      expect(json['receipt_id'], isNotNull);
      expect(json['receipt_id'].toString(), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-07: Digest change detection ────────────────────────────────────

  group('M2-INT-07: Stale receipt invalidation (real digest)', () {
    test('receipt with current digest is not stale', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      final currentDigest = r.trustStateDigest;

      final receipt = RelianceReceipt(
        receiptId: 'rr-qual-001',
        publicId: _qualSubjectId,
        physicalSubjectId: r.physicalSubjectId,
        trustStateDigest: currentDigest,
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime.now().toUtc(),
        validityState: ReceiptValidityState.valid,
      );
      expect(receipt.isStaleFor(currentDigest), false);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('receipt with old digest is stale', () async {
      final receipt = RelianceReceipt(
        receiptId: 'rr-qual-002',
        publicId: _qualSubjectId,
        physicalSubjectId: 'phys-qual-old',
        trustStateDigest: 'sha256:old000000000000000000000000000000000000000000000000000000000dead',
        purpose: ActionabilityPurpose.purchase,
        decision: ActionabilityDecision.allow,
        createdAt: DateTime.now().toUtc(),
        validityState: ReceiptValidityState.valid,
      );

      final r = await client.getMachineTrust(_qualSubjectId);
      final isStale = receipt.isStaleFor(r.trustStateDigest);
      // Real digest is different from the fake old digest → receipt is stale.
      expect(isStale, true);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── M2-INT-08: Freshness state ────────────────────────────────────────────

  group('M2-INT-08: Freshness state from real backend', () {
    test('freshness state is a known value', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      final knownStates = ['CURRENT', 'APPROACHING_STALE', 'STALE', 'EXPIRED', 'REVERIFY_REQUIRED', 'UNKNOWN'];
      expect(knownStates, contains(r.freshnessState));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('asOf timestamp is parseable', () async {
      final r = await client.getMachineTrust(_qualSubjectId);
      if (r.asOf.isNotEmpty) {
        final parsed = DateTime.tryParse(r.asOf);
        expect(parsed, isNotNull);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
