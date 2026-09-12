import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:provenance_verified_app/submit/models/submit_models.dart';

void main() {
  group('M4 canonical customer contract', () {
    test('service tiers use the web contract and canonical prices', () {
      expect(ServiceTier.t1Free.apiValue, 'T1');
      expect(ServiceTier.t2Standard.apiValue, 'T2');
      expect(ServiceTier.t3Professional.apiValue, 'T3');
      expect(ServiceTier.t4Certified.apiValue, 'T4');

      expect(ServiceTier.t1Free.priceRange, 'Free');
      expect(ServiceTier.t2Standard.priceRange, '\$50');
      expect(ServiceTier.t3Professional.priceRange, '\$150');
      expect(ServiceTier.t4Certified.priceRange, '\$350');
    });

    test('quote parses canonical cents, CSA version and payment authority', () {
      final quote = SubmissionQuote.fromJson({
        'ok': true,
        'data': {
          'service_code': 'T3_EVIDENCE_VERIFIED',
          'service_description': 'Evidence-Verified Provenance',
          'tier': 'T3',
          'base_fee_cents': 15000,
          'currency': 'USD',
          'price_version': 'T3_150_BASELINE_V1',
          'csa_version': 'PV-CSA-TEST',
          'payment_required': true,
        },
      });

      expect(quote.serviceCode, 'T3_EVIDENCE_VERIFIED');
      expect(quote.price, 150.0);
      expect(quote.csaVersion, 'PV-CSA-TEST');
      expect(quote.paymentRequired, isTrue);
    });

    test('T1 quote remains free and does not require Stripe', () {
      final quote = SubmissionQuote.fromJson({
        'data': {
          'service_code': 'T1_FREE_ASSET_FINGERPRINT',
          'tier': 'T1',
          'base_fee_cents': 0,
          'currency': 'USD',
          'price_version': 'T1_FREE_BASELINE_V1',
          'csa_version': 'PV-CSA-TEST',
          'payment_required': false,
        },
      });
      expect(quote.price, 0);
      expect(quote.paymentRequired, isFalse);
    });

    test('payment coordinator never carries caller price authority', () {
      final source = File('lib/submit/providers/payment_coordinator.dart').readAsStringSync();
      expect(source, contains('/api/v1/payments/orders'));
      expect(source, contains('/api/v1/payments/checkout'));
      expect(source, contains("'order_id': orderId"));
      expect(source, isNot(contains("'amount_cents'")));
      expect(source, isNot(contains("'stripe_price_id'")));
      expect(source, isNot(contains("'payment_intent_id'")));
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
