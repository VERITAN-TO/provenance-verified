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

    test('native start and settlement carry no client tier or price authority', () {
      final submit = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      final payment = File('lib/submit/providers/payment_coordinator.dart').readAsStringSync();

      expect(submit, contains("_postJson('/api/v1/customer/submissions/start', const {})"));
      expect(submit, contains('submitForEvaluation'));
      expect(submit, contains('/submit'));
      expect(submit, isNot(contains("'requested_service_tier'")));

      expect(payment, contains("'submissionId': submissionId"));
      expect(payment, isNot(contains("'serviceCode': quote.serviceCode")));
      expect(payment, isNot(contains("'amount_cents'")));
      expect(payment, isNot(contains("'stripe_price_id'")));
      expect(payment, isNot(contains("'payment_intent_id'")));
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
  });
}
