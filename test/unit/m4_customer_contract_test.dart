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

    test('T4 determination does not grant Gold Seal or official credential', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Must explicitly state credential separation for T4
      expect(screen, contains('signing, issuance, or registry activation'));
      expect(screen, isNot(contains('T4 — PV GOLD SEAL')));
    });
  });
}
