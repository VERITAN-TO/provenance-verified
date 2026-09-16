import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:provenance_verified_app/submit/models/submit_models.dart';

void main() {
  group('M4 canonical customer contract', () {
    test('tier ladder is educational and settlement follows determination', () {
      expect(ServiceTier.t1Free.apiValue, 'T1');
      expect(ServiceTier.t2Standard.apiValue, 'T2');
      expect(ServiceTier.t3Professional.apiValue, 'T3');
      expect(ServiceTier.t4Certified.apiValue, 'T4');

      expect(ServiceTier.t1Free.priceRange, 'Free if determined T1');
      expect(ServiceTier.t2Standard.priceRange, '\$50 if determined T2');
      expect(ServiceTier.t3Professional.priceRange, '\$150 if determined T3');
      expect(ServiceTier.t4Certified.priceRange, '\$350 if evidence determines T4');
      expect(ServiceTier.t4Certified.machineTrustState, contains('GOLD SEAL AUTHORITY SEPARATE'));
    });

    test('quote parses determined tier and determination evidence', () {
      final quote = SubmissionQuote.fromJson({
        'ok': true,
        'data': {
          'service_code': 'T3_EVIDENCE_VERIFIED',
          'service_description': 'Evidence-Established Trust',
          'determined_tier': 'T3',
          'base_fee_cents': 15000,
          'currency': 'USD',
          'price_version': 'T3_150_BASELINE_V1',
          'csa_version': 'PV-CSA-TEST',
          'payment_required': true,
          'determination_id': 'det-1',
          'determination_digest': 'sha256:abc',
          'why_this_tier': 'Evidence supports T3',
          'why_not_next_tier': 'T4 authority prerequisites not met',
          'limitations': ['scope limited'],
        },
      });

      expect(quote.tier, 'T3');
      expect(quote.price, 150.0);
      expect(quote.csaVersion, 'PV-CSA-TEST');
      expect(quote.paymentRequired, isTrue);
      expect(quote.determinationId, 'det-1');
      expect(quote.determinationDigest, 'sha256:abc');
      expect(quote.whyThisTier, 'Evidence supports T3');
      expect(quote.limitations, contains('scope limited'));
    });

    test('T1 determined result remains free and does not require Stripe', () {
      final quote = SubmissionQuote.fromJson({
        'data': {
          'service_code': 'T1_FREE_ASSET_FINGERPRINT',
          'determined_tier': 'T1',
          'base_fee_cents': 0,
          'currency': 'USD',
          'price_version': 'T1_FREE_BASELINE_V1',
          'csa_version': 'PV-CSA-TEST',
          'payment_required': false,
        },
      });
      expect(quote.tier, 'T1');
      expect(quote.price, 0);
      expect(quote.paymentRequired, isFalse);
    });

    test('native evaluation and settlement carry no client tier or price authority', () {
      final submit = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      final payment = File('lib/submit/providers/payment_coordinator.dart').readAsStringSync();

      expect(submit, contains("_postJson('/api/v1/customer/submissions/start', const {})"));
      expect(submit, contains("/api/v1/customer/submissions/\$submissionId/evaluate"));
      expect(submit, isNot(contains("/api/v1/customer/submissions/\$submissionId/submit")));
      expect(submit, isNot(contains("'requested_service_tier'")));

      expect(payment, contains("'submissionId': submissionId"));
      expect(payment, isNot(contains("'serviceCode': quote.serviceCode")));
      expect(payment, isNot(contains("'amount_cents'")));
      expect(payment, isNot(contains("'stripe_price_id'")));
      expect(payment, isNot(contains("'payment_intent_id'")));
    });

    test('both free and paid determinations bind canonical settlement explicitly', () {
      final submit = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(submit, contains('Both FREE and PAID orders must be explicitly bound after determination.'));
      expect(submit, contains('_payment.bindSettlement'));
      expect(submit, isNot(contains('T1 free order is bound server-side when it is created.')));
    });

    test('tier cards are informational, not customer-selection controls', () {
      final card = File('lib/submit/widgets/service_tier_card.dart').readAsStringSync();
      expect(card, contains('educational PV trust-ladder card'));
      expect(card, contains('Your evidence determines whether this state is earned.'));
      expect(card, isNot(contains('Select service path')));
      expect(card, isNot(contains('Requested service selected')));
    });

    test('expired-session paths call the real auth refresh notifier', () {
      final submit = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      final activity = File('lib/activity/providers/activity_provider.dart').readAsStringSync();
      final myPv = File('lib/my_pv/providers/my_pv_provider.dart').readAsStringSync();
      expect(submit, contains('authProvider.notifier).refresh()'));
      expect(activity, contains('authProvider.notifier).refresh()'));
      expect(myPv, contains('authProvider.notifier).refresh()'));
    });

    test('submit screen is educational trust ladder with no customer tier authority', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();

      // Trust ladder education must be present
      expect(screen, contains('PV TRUST LADDER'));
      expect(screen, contains('DETERMINATION & PRICING'));
      expect(screen, contains('SETTLEMENT'));

      // Stale storefront strings must be absent
      expect(screen, isNot(contains('Please select a service tier')));
      expect(screen, isNot(contains('Select Requested Service')));
      expect(screen, isNot(contains('requested service tier')));
      expect(screen, isNot(contains('selectTier(')));

      // Source order: saveDeclarations before submitForEvaluation before fetchQuote
      final savePos     = screen.indexOf('saveDeclarations()');
      final evalPos     = screen.indexOf('submitForEvaluation()');
      final quotePos    = screen.indexOf('fetchQuote()');
      expect(savePos,  greaterThan(-1), reason: 'saveDeclarations() must be present');
      expect(evalPos,  greaterThan(-1), reason: 'submitForEvaluation() must be present');
      expect(quotePos, greaterThan(-1), reason: 'fetchQuote() must be present');
      expect(savePos,  lessThan(evalPos),  reason: 'saveDeclarations must precede submitForEvaluation');
      expect(evalPos,  lessThan(quotePos), reason: 'submitForEvaluation must precede fetchQuote');
    });

    test('settlement cannot precede canonical determination', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // settleDeterminedResult is only in case 5 (after fetchQuote in case 3)
      final quotePos    = screen.indexOf('fetchQuote()');
      final settlePos   = screen.indexOf('settleDeterminedResult()');
      expect(settlePos, greaterThan(-1), reason: 'settleDeterminedResult() must be present');
      expect(quotePos,  lessThan(settlePos), reason: 'fetchQuote must precede settleDeterminedResult');
    });

    // R12 semantic regression locks — added by PV-M2-LEAD-C-NATIVE-SEMANTIC-EXEC-R12
    test('submit screen uses canonical tier names and evidence-and-policy authority', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();

      // REVIEWER_SELECTS_TIER=FALSE: "review team" must not appear as tier-selection authority
      expect(screen, isNot(contains('determined by the review team')));
      expect(screen, isNot(contains('exclusively by the PROVENANCE VERIFIED™ review team')));

      // Canonical T1–T4 names must be present
      expect(screen, contains('Accountable Existence'));
      expect(screen, contains('Accountable Declaration'));
      expect(screen, contains('Evidence-Established Trust'));
      expect(screen, contains('Highest Governed Provenance Authority'));

      // Stale tier names must be absent
      expect(screen, isNot(contains('SELF-REPORTED')));
      expect(screen, isNot(contains('DECLARED SOURCE')));
      expect(screen, isNot(contains('EVIDENCE VERIFIED')));
      expect(screen, isNot(contains('PV GOLD SEAL')));

      // T1 must not claim provenance fingerprint
      expect(screen, isNot(contains('provenance fingerprint')));

      // T4 Gold Seal separation must be stated
      expect(screen, contains('Determination alone does not grant'));
      expect(screen, contains('Gold Seal'));

      // Evidence and policy as authority
      expect(screen, contains('evidence and policy'));
    });

    test('activity screen does not project requested tier as trust state', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();

      // Must not render customer-requested tier as a trust state before determination
      expect(activity, isNot(contains("'Requested: \${item.requestedServiceTier}'")));
      expect(activity, isNot(contains('"Requested: "')));

      // Must show neutral bounded state before determination
      expect(activity, contains('Awaiting determination'));
    });

    test('activity model marks requestedServiceTier as decode-only', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();

      // Decode-only annotation must be present
      expect(model, contains('Decode-only'));
      expect(model, contains('Must not be projected as current trust authority'));
    });

    test('submission detail screen does not project requestedServiceTier as trust state', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();

      // Must not render customer-requested service tier as a trust state
      expect(screen, isNot(contains("'Requested Service'")));
      expect(screen, isNot(contains('requestedServiceTier')));
    });

    test('T4 determination does not grant Gold Seal or official credential', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Must explicitly state credential separation for T4
      expect(screen, contains('signing, issuance, or registry activation'));
      expect(screen, isNot(contains('T4 — PV GOLD SEAL')));
    });

    // R13 semantic regression locks — added by PV-M2-LEAD-C-R13-NATIVE-OPERATIONAL
    test('scanner navigates to canonical /verify/manual route, not bare /manual', () {
      final scanner = File('lib/scanner/screens/scanner_screen.dart').readAsStringSync();
      expect(scanner, contains("'/verify/manual'"));
      expect(scanner, isNot(contains("'/manual'")));
    });

    test('trust result screen links to /my-pv/receipts, not bare /receipts', () {
      final trust = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(trust, contains("'/my-pv/receipts'"));
      expect(trust, isNot(contains("'/receipts'")));
    });

    test('receipt list screen links to /my-pv/receipts/:id, not bare /receipts/:id', () {
      final list = File('lib/reliance/screens/receipt_list_screen.dart').readAsStringSync();
      expect(list, contains("'/my-pv/receipts/"));
      expect(list, isNot(contains("'/receipts/")));
    });

    test('asset detail screen links to /my-pv/receipts/:id, not bare /receipts/:id', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, contains("'/my-pv/receipts/"));
      expect(detail, isNot(contains("'/receipts/")));
    });

    test('my PV screen tier labels do not use Gold or stale names', () {
      final screen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      // Must not use Gold or stale FINGERPRINT/DECLARED/VERIFIED abbreviations for T4
      expect(screen, isNot(contains("'T4 GOLD'")));
      expect(screen, isNot(contains("'T4 GOLD STANDARD'")));
      // Must use canonical governed authority label for T4
      expect(screen, contains('T4 GOVERNED AUTHORITY'));
    });

    test('asset detail tier badge does not assert Gold Standard for T4', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      // T4 GOLD STANDARD implies credential not earned by determination alone
      expect(detail, isNot(contains('T4 GOLD STANDARD')));
      expect(detail, isNot(contains('T4 GOLD')));
      expect(detail, contains('T4 — GOVERNED AUTHORITY'));
    });

    // R13 C13-4/C13-5/C13-7 regression locks
    test('trust badge does not assert Gold Standard or Gold Seal for T4', () {
      final badge = File('lib/trust/widgets/trust_badge.dart').readAsStringSync();
      expect(badge, isNot(contains('T4 GOLD STANDARD')));
      expect(badge, isNot(contains('T4 GOLD SEAL')));
      expect(badge, isNot(contains("'T4 GOLD'")));
      expect(badge, contains('T4 — GOVERNED AUTHORITY'));
    });

    test('trust result screen surfaces lifecycle state before trust badge', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      // Lifecycle banner must appear before StaleBanner in source order
      final lifecyclePos = screen.indexOf('_LifecycleBanner');
      final stalePos     = screen.indexOf('StaleBanner');
      expect(lifecyclePos, greaterThan(-1), reason: '_LifecycleBanner must be present');
      expect(stalePos,     greaterThan(-1), reason: 'StaleBanner must be present');
      expect(lifecyclePos, lessThan(stalePos), reason: 'lifecycle must precede stale banner');
      // Must handle SUSPENDED and REVOKED as do-not-rely states
      expect(screen, contains('SUSPENDED'));
      expect(screen, contains('REVOKED'));
      expect(screen, contains('SUPERSEDED'));
    });

    test('trust result screen error view has retry capability', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      // _ErrorView must be a ConsumerWidget with a retry mechanism
      expect(screen, contains('ConsumerWidget'));
      expect(screen, contains('ref.invalidate(trustRecordProvider(publicId))'));
      expect(screen, contains("const Text('Retry')"));
    });

    test('scanner screen camera area has accessibility semantics label', () {
      final scanner = File('lib/scanner/screens/scanner_screen.dart').readAsStringSync();
      expect(scanner, contains('Camera viewfinder'));
      expect(scanner, contains('Semantics('));
    });

    test('trust result info rows combine label and value for screen readers', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      // _InfoRow must use Semantics with combined label for accessibility
      expect(screen, contains('excludeSemantics: true'));
    });

    // R14 semantic regression locks — added by PV-M2-LEAD-C-NATIVE-R14-CONTRACT-REBIND-RELEASE-CUSTODY
    test('quote parser reads why_not_higher with fallback to why_not_next_tier', () {
      // PR #47 backend sends why_not_higher; native must read that key first.
      final model = File('lib/submit/models/submit_models.dart').readAsStringSync();
      expect(model, contains("data['why_not_higher']"));
      expect(model, contains("data['why_not_next_tier']"));
    });

    test('determination result parser reads why_not_higher and handles array why_this_tier', () {
      // PR #47 server sends why_not_higher (not why_not_next_tier) and why_this_tier as array.
      // DeterminationResult must not cast why_this_tier directly as String? — that throws on arrays.
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains("j['why_not_higher']"));
      expect(model, contains("j['why_not_next_tier']"));
      // Array guard must be present
      expect(model, contains('is List'));
      // Unsafe bare cast must be absent
      expect(model, isNot(contains("j['why_this_tier'] as String?")));
    });

    test('determination result parser does not cast why_this_tier directly as String', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, isNot(contains("as String?\n      whyNotNextTier: j['why_not_next_tier']")));
    });

    // R15 semantic regression locks — added by PV-M2-LEAD-C-NATIVE-CONTINUE-18DB1C2-R15
    test('lifecycle banner suppresses non-actionable states such as UNKNOWN and ACTIVE', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      // actionableStates guard must be present — prevents "Status: UNKNOWN" banner on normal records
      expect(screen, contains('actionableStates'));
      expect(screen, contains("'SUSPENDED'"));
      expect(screen, contains("'REVOKED'"));
      expect(screen, contains("'SUPERSEDED'"));
      // Guard must precede the switch
      final guardPos  = screen.indexOf('actionableStates.contains(status)');
      final switchPos = screen.indexOf('switch (status)');
      expect(guardPos, greaterThan(-1), reason: 'actionableStates guard must be present');
      expect(switchPos, greaterThan(-1), reason: 'switch (status) must be present');
      expect(guardPos, lessThan(switchPos), reason: 'guard must precede the switch');
    });

    // R16 semantic regression locks — added by PV-M2-LEAD-C-NATIVE-CONTINUE-FE01562-R16
    test('ADDITIONAL_INFO_REQUESTED is a named status value, not decoded as unknown', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // Must be declared in the enum
      expect(model, contains('additionalInfoRequested'));
      // Must be mapped from the wire string
      expect(model, contains("'ADDITIONAL_INFO_REQUESTED'"));
      // Must not fall through to unknown
      expect(model, isNot(contains("'ADDITIONAL_INFO_REQUESTED':  return SubmissionStatus.unknown")));
    });

    test('evidence request section shows for both MORE_INFORMATION_REQUIRED and ADDITIONAL_INFO_REQUESTED', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // Both statuses must gate the evidence-request section
      expect(screen, contains('moreInformationRequired'));
      expect(screen, contains('additionalInfoRequested'));
    });

    test('custody timeline items have semantics labels for screen readers', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // _TimelineItem must wrap with Semantics for accessibility
      expect(screen, contains('Semantics('));
      expect(screen, contains('excludeSemantics: true'));
    });
  });
}
