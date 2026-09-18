import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

      expect(screen, contains('PV TRUST LADDER'));
      expect(screen, contains('DETERMINATION & PRICING'));
      expect(screen, contains('SETTLEMENT'));

      expect(screen, isNot(contains('Please select a service tier')));
      expect(screen, isNot(contains('Select Requested Service')));
      expect(screen, isNot(contains('requested service tier')));
      expect(screen, isNot(contains('selectTier(')));

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
      final quotePos    = screen.indexOf('fetchQuote()');
      final settlePos   = screen.indexOf('settleDeterminedResult()');
      expect(settlePos, greaterThan(-1), reason: 'settleDeterminedResult() must be present');
      expect(quotePos,  lessThan(settlePos), reason: 'fetchQuote must precede settleDeterminedResult');
    });

    test('submit screen uses canonical tier names and evidence-and-policy authority', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();

      expect(screen, isNot(contains('determined by the review team')));
      expect(screen, isNot(contains('exclusively by the PROVENANCE VERIFIED™ review team')));

      expect(screen, contains('Accountable Existence'));
      expect(screen, contains('Accountable Declaration'));
      expect(screen, contains('Evidence-Established Trust'));
      expect(screen, contains('Highest Governed Provenance Authority'));

      expect(screen, isNot(contains('SELF-REPORTED')));
      expect(screen, isNot(contains('DECLARED SOURCE')));
      expect(screen, isNot(contains('EVIDENCE VERIFIED')));
      expect(screen, isNot(contains('PV GOLD SEAL')));

      expect(screen, isNot(contains('provenance fingerprint')));

      expect(screen, contains('Determination alone does not grant'));
      expect(screen, contains('Gold Seal'));

      expect(screen, contains('evidence and policy'));
    });

    test('activity screen does not project requested tier as trust state', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();

      expect(activity, isNot(contains("'Requested: \${item.requestedServiceTier}'")));
      expect(activity, isNot(contains('"Requested: "')));

      expect(activity, contains('Awaiting determination'));
    });

    test('activity model marks requestedServiceTier as decode-only', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();

      expect(model, contains('Decode-only'));
      expect(model, contains('Must not be projected as current trust authority'));
    });

    test('submission detail screen does not project requestedServiceTier as trust state', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();

      expect(screen, isNot(contains("'Requested Service'")));
      expect(screen, isNot(contains('requestedServiceTier')));
    });

    test('T4 determination does not grant Gold Seal or official credential', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(screen, contains('signing, issuance, or registry activation'));
      expect(screen, isNot(contains('T4 — PV GOLD SEAL')));
    });

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
      expect(screen, isNot(contains("'T4 GOLD'")));
      expect(screen, isNot(contains("'T4 GOLD STANDARD'")));
      expect(screen, contains('T4 — Highest Governed Provenance Authority'));
    });

    test('asset detail tier badge does not assert Gold Standard for T4', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('T4 GOLD STANDARD')));
      expect(detail, isNot(contains('T4 GOLD')));
      expect(detail, contains('T4 — GOVERNED AUTHORITY'));
    });

    test('trust badge does not assert Gold Standard or Gold Seal for T4', () {
      final badge = File('lib/trust/widgets/trust_badge.dart').readAsStringSync();
      expect(badge, isNot(contains('T4 GOLD STANDARD')));
      expect(badge, isNot(contains('T4 GOLD SEAL')));
      expect(badge, isNot(contains("'T4 GOLD'")));
      expect(badge, contains('T4 — GOVERNED AUTHORITY'));
    });

    test('trust result screen surfaces lifecycle state before trust badge', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      final lifecyclePos = screen.indexOf('_LifecycleBanner');
      final stalePos     = screen.indexOf('StaleBanner');
      expect(lifecyclePos, greaterThan(-1), reason: '_LifecycleBanner must be present');
      expect(stalePos,     greaterThan(-1), reason: 'StaleBanner must be present');
      expect(lifecyclePos, lessThan(stalePos), reason: 'lifecycle must precede stale banner');
      expect(screen, contains('SUSPENDED'));
      expect(screen, contains('REVOKED'));
      expect(screen, contains('SUPERSEDED'));
    });

    test('trust result screen error view has retry capability', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
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
      expect(screen, contains('excludeSemantics: true'));
    });

    test('quote parser reads why_not_higher with fallback to why_not_next_tier', () {
      final model = File('lib/submit/models/submit_models.dart').readAsStringSync();
      expect(model, contains("data['why_not_higher']"));
      expect(model, contains("data['why_not_next_tier']"));
    });

    test('determination result parser reads why_not_higher and handles array why_this_tier', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains("j['why_not_higher']"));
      expect(model, contains("j['why_not_next_tier']"));
      expect(model, contains('is List'));
      expect(model, isNot(contains("j['why_this_tier'] as String?")));
    });

    test('determination result parser does not cast why_this_tier directly as String', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, isNot(contains("as String?\n      whyNotNextTier: j['why_not_next_tier']")));
    });

    test('lifecycle banner suppresses non-actionable states such as UNKNOWN and ACTIVE', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(screen, contains('actionableStates'));
      expect(screen, contains("'SUSPENDED'"));
      expect(screen, contains("'REVOKED'"));
      expect(screen, contains("'SUPERSEDED'"));
      final guardPos  = screen.indexOf('actionableStates.contains(status)');
      final switchPos = screen.indexOf('switch (status)');
      expect(guardPos, greaterThan(-1), reason: 'actionableStates guard must be present');
      expect(switchPos, greaterThan(-1), reason: 'switch (status) must be present');
      expect(guardPos, lessThan(switchPos), reason: 'guard must precede the switch');
    });

    test('ADDITIONAL_INFO_REQUESTED is a named status value, not decoded as unknown', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('additionalInfoRequested'));
      expect(model, contains("'ADDITIONAL_INFO_REQUESTED'"));
      expect(model, isNot(contains("'ADDITIONAL_INFO_REQUESTED':  return SubmissionStatus.unknown")));
    });

    test('evidence request section shows for both MORE_INFORMATION_REQUIRED and ADDITIONAL_INFO_REQUESTED', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(screen, contains('moreInformationRequired'));
      expect(screen, contains('additionalInfoRequested'));
    });

    test('custody timeline items have semantics labels for screen readers', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(screen, contains('Semantics('));
      expect(screen, contains('excludeSemantics: true'));
    });

    test('determination section surface law: server-determined tier, CUSTOMER_SELECTS_TIER=FALSE, no Gold Seal', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(screen, contains('CUSTOMER_SELECTS_TIER = FALSE'));
      expect(screen, contains('DETERMINATION RESULT'));
      expect(screen, contains('det.tier'));
      expect(screen, isNot(contains("'T4 — PV GOLD SEAL'")));
      expect(screen, isNot(contains("'T4 GOLD SEAL'")));
      expect(screen, contains('WHY THIS TIER'));
      expect(screen, contains('WHY NOT HIGHER'));
      expect(screen, contains('LIMITATIONS'));
    });

    test('activity list projects server determination only, BILLING_FOLLOWS_DETERMINATION surface', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, contains('Server-authored determination result'));
      expect(activity, contains("'Determined: \${item.determinedTier}'"));
      expect(activity, isNot(contains("'Determined: T4 GOLD'")));
      expect(activity, isNot(contains("'T4 GOLD SEAL'")));
    });

    test('no funded/payment-grants-tier language in native activity — BILLING_FOLLOWS_DETERMINATION', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, isNot(contains('verification is funded')));
      expect(activity, isNot(contains('Your verification is')));
      expect(activity, isNot(contains('payment grants')));
      expect(activity, isNot(contains('PAYMENT_GRANTS')));
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('verification is funded')));
      expect(detail, isNot(contains('payment grants')));
    });

    test('no native pricing page or PricingTierCTA — CUSTOMER_SELECTS_TIER=FALSE on pricing surface', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('pricing_tier_selected')));
      expect(submit, isNot(contains('PricingTierCTA')));
      expect(submit, isNot(contains('/checkout?service=')));
      expect(submit, isNot(contains('Get T2')));
      expect(submit, isNot(contains('Get T3')));
      expect(submit, isNot(contains('Get T4')));
    });

    test('ServiceTierCard has no selection params — CUSTOMER_SELECTS_TIER=FALSE on tier display widget', () {
      final card = File('lib/submit/widgets/service_tier_card.dart').readAsStringSync();
      expect(card, isNot(contains('isSelected')));
      expect(card, isNot(contains('onSelect')));
      expect(card, isNot(contains('VoidCallback')));
      expect(card, contains('Your evidence determines whether this state is earned.'));
    });

    test('SubmissionDraft has no selectedTier field — CUSTOMER_SELECTS_TIER=FALSE in submit model', () {
      final models = File('lib/submit/models/submit_models.dart').readAsStringSync();
      expect(models, isNot(contains('selectedTier')));
      expect(models, isNot(contains('Deprecated compatibility field')));
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, isNot(contains('selectTier')));
      expect(provider, isNot(contains('@Deprecated')));
    });

    test('no customer-selectable checkout path — CUSTOMER_SELECTS_TIER=FALSE on settlement surface', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('/checkout?service=')));
      expect(submit, isNot(contains("serviceCode: draft.selectedTier")));
      expect(submit, isNot(contains("'checkout?service='")));
      expect(submit, contains('DETERMINATION'));
    });

    test('C20-1: router errorBuilder has bounded not-found recovery — no raw URI dump', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      expect(router, isNot(contains("'Page not found: \${state.uri}'")));
      expect(router, contains("context.go('/verify')"));
      expect(router, contains('Semantics'));
      expect(router, contains("import '../../design/pv_colors.dart'"));
    });

    test('C20-2: TrustResultScreen._ErrorView distinguishes not-found from generic errors', () {
      final trust = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(trust, contains('isNotFound'));
      expect(trust, contains('Semantics'));
      expect(trust, contains("'Go Back'"));
      expect(trust, contains("'Retry'"));
    });

    test('C20-3: ReceiptDetailScreen has bounded error and not-found states — no naked Text(e.toString())', () {
      final receipt = File('lib/reliance/screens/receipt_detail_screen.dart').readAsStringSync();
      expect(receipt, isNot(contains('Center(child: Text(e.toString()))')));
      expect(receipt, isNot(contains("const Center(child: Text('Receipt not found'))")));
      expect(receipt, contains('Semantics'));
      expect(receipt, contains("'Go Back'"));
    });

    test('C20-4: RelianceScreen blocks reliance for REVOKED/SUSPENDED lifecycle states', () {
      final reliance = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      expect(reliance, contains('lifecycleBlocked'));
      expect(reliance, contains('REVOKED'));
      expect(reliance, contains('SUSPENDED'));
      expect(reliance, contains('lifecycleBlocked'));
      expect(reliance, contains('LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY'));
    });

    test('C20-5: submit wizard has auth recovery redirect on 401 — terminal auth failure sends to sign-in', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('e.statusCode == 401'));
      expect(submit, contains("'/sign-in"));
      expect(submit, contains('context.push'));
    });

    test('C20-6: submit wizard re-fetches quote on re-entry at step 4+ — interruption recovery', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('draft.step >= 4'));
      expect(submit, contains('_refetchQuote'));
      expect(submit, contains('Future<void> _refetchQuote()'));
    });

    test('C20-7: Android manifest has pv:// deep-link intent-filter — iOS/Android parity', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:scheme="pv"'));
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android.intent.category.BROWSABLE'));
    });

    test('C20-8: AssetDetailScreen._ErrorView has distinct not-found recovery — no misleading Pull down to retry for 404', () {
      final asset = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(asset, contains('isNotFound'));
      expect(asset, contains("'Return to My PV'"));
      expect(asset, contains('Semantics'));
    });

    test('C20-9: SubmissionDetail.requestedServiceTier has decode-only annotation in activity_models — not rendered as trust authority', () {
      final activity = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(activity, contains('Decode-only: retained for backward-compat JSON parsing only'));
      final first = activity.indexOf('Decode-only: retained for backward-compat JSON parsing only');
      final last = activity.lastIndexOf('Decode-only: retained for backward-compat JSON parsing only');
      expect(first, isNot(equals(last)), reason: 'decode-only annotation must appear in both SubmissionStatusItem and SubmissionDetail');
    });

    test('C20-10: ServiceTier.serviceCode annotated as not-for-client-submission — GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY law present', () {
      final models = File('lib/submit/models/submit_models.dart').readAsStringSync();
      expect(models, contains('NEVER sent to the server'));
      expect(models, contains('GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE'));
    });

    test('C20-11: MyPvScreen._ErrorView has Semantics + Retry button + 401 auth detection + spinner semanticsLabel', () {
      final myPv = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      expect(myPv, contains('Semantics'));
      expect(myPv, contains("'401'"));
      expect(myPv, contains("'Retry'"));
      expect(myPv, contains('customerAssetsProvider'));
      expect(myPv, contains("semanticsLabel: 'Loading your assets'"));
    });

    test('C20-12: WhyThisTierScreen — T4 description must not say "Gold Standard"; must reference governed authority and separate issuance', () {
      final why = File('lib/trust/screens/why_this_tier_screen.dart').readAsStringSync();
      expect(why, isNot(contains('Gold Standard')));
      expect(why, contains('Governed Provenance Authority'));
      expect(why, contains('Gold Seal'));
    });

    test('C20-13: WhyNotHigherScreen — T4 banner must not say "Gold Standard"; must reference governed authority', () {
      final why = File('lib/trust/screens/why_not_higher_screen.dart').readAsStringSync();
      expect(why, isNot(contains('Gold Standard')));
      expect(why, contains('Governed Provenance Authority'));
      expect(why, contains('Gold Seal'));
    });

    test('C20-14: ReceiptListScreen has styled error view with Semantics + Retry + spinner semanticsLabel', () {
      final receipts = File('lib/reliance/screens/receipt_list_screen.dart').readAsStringSync();
      expect(receipts, contains("semanticsLabel: 'Loading reliance receipts'"));
      expect(receipts, contains('Semantics'));
      expect(receipts, contains("'Retry'"));
      expect(receipts, contains('receiptListProvider'));
      expect(receipts, isNot(contains('Center(child: Text(e.toString()))')));
    });

    test('C20-15: Trust detail sub-screens (WhyThis, WhyNotHigher, Authority) have styled error + spinner semanticsLabel', () {
      for (final path in [
        'lib/trust/screens/why_this_tier_screen.dart',
        'lib/trust/screens/why_not_higher_screen.dart',
        'lib/trust/screens/authority_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('Center(child: Text(e.toString()))')), reason: '$path must not have raw error display');
        expect(src, contains('Semantics'), reason: '$path must have Semantics on error state');
        expect(src, contains("'Retry'"), reason: '$path must have Retry button');
        expect(src, contains('semanticsLabel:'), reason: '$path must have spinner semanticsLabel');
      }
    });

    test('C21-1: SubmitScreen — no "review team" as tier selector; canonical T1-T4 names present', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('review team')));
      expect(submit, contains('T1 — Accountable Existence'));
      expect(submit, contains('T2 — Accountable Declaration'));
      expect(submit, contains('T3 — Evidence-Established Trust'));
      expect(submit, contains('T4 — Highest Governed Provenance Authority'));
    });

    test('C21-2: SubmitScreen — no T4 Gold Seal label; Gold Seal requires separate authority', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('PV GOLD SEAL')));
      expect(submit, contains('Gold Seal'));
      expect(submit, contains('T4_DETERMINATION_IS_OFFICIAL_T4=FALSE'));
    });

    test('C21-3: SubmitScreen — no provenance fingerprint language; no SELF-REPORTED label', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('provenance fingerprint')));
      expect(submit, isNot(contains('SELF-REPORTED')));
    });

    test('C21-4: SubmitScreen — determination-first control flow; evaluation precedes payment', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      final saveIdx = submit.indexOf('saveDeclarations');
      final evalIdx = submit.indexOf('submitForEvaluation');
      final quoteIdx = submit.indexOf('fetchQuote');
      expect(saveIdx, isNot(-1), reason: 'saveDeclarations must be present');
      expect(evalIdx, isNot(-1), reason: 'submitForEvaluation must be present');
      expect(quoteIdx, isNot(-1), reason: 'fetchQuote must be present');
      expect(saveIdx, lessThan(evalIdx), reason: 'saveDeclarations must precede submitForEvaluation');
      expect(evalIdx, lessThan(quoteIdx), reason: 'submitForEvaluation must precede fetchQuote');
    });

    test('C21-5: ActivityScreen — no "certification" language for empty-state CTA; must use evaluation framing', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, isNot(contains('Submit a gemstone for certification')));
      expect(activity, contains('PROVENANCE VERIFIED'));
    });

    test('C21-6: ActivityScreen — no customer-facing "Requested:" tier fallback', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, isNot(contains("'Requested: \${item.requestedServiceTier}'")));
      expect(activity, isNot(contains('"Requested: ')));
    });

    test('C21-7: SubmissionDetailScreen — no "Requested Service" tier displayed as trust authority', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains("'Requested Service'")));
      expect(detail, isNot(contains('"Requested Service"')));
      expect(detail, isNot(contains('requestedServiceTier')));
    });

    test('C21-8: No selectTier / selectedTier in submit or activity screens — CUSTOMER_SELECTS_TIER=FALSE', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('selectTier')));
      expect(submit, isNot(contains('selectedTier')));
      expect(activity, isNot(contains('selectTier')));
      expect(activity, isNot(contains('selectedTier')));
    });

    test('C22-1: Evidence upload multipart carries explicit trust-law classification — not inferred from missing fields', () {
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, contains("'independent'"));
      expect(provider, contains("'false'"));
      expect(provider, contains("'related_party'"));
      expect(provider, contains("'true'"));
      expect(provider, contains("'qualified_review_eligible'"));
      expect(provider, contains('CUSTOMER_UPLOAD_AUTO_INDEPENDENT=FALSE'));
      expect(provider, contains('CUSTOMER_UPLOAD_AUTO_QUALIFIED=FALSE'));
    });

    test('C22-2: SubmissionDetail decodes public_id → publicId and determinedAt; R32: payment-gated Public Verify removed', () {
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains("json['public_id']"));
      expect(models, contains('publicId'));
      expect(models, contains("json['determined_at']"));
      expect(models, contains('determinedAt'));
      expect(models, contains('MTA-1: SERVER DETERMINES TRUST'));
      expect(models, contains('hasSettlementSeam'));
      expect(models, contains('settlementData'));
      expect(models, contains("json.containsKey('settlement')"));
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(models, contains('publicId'));
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      expect(detail, contains('_ProvenanceRecordAction removed in R32'));
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      expect(detail, isNot(contains('settlementData!.isSettled')));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
      expect(detail, contains('hasSettlementSeam'));
      expect(detail, contains('Semantics'));
    });

    test('C23-1: auth screens use go_router context.go — no Navigator.pushReplacementNamed', () {
      final signIn = File('lib/auth/screens/sign_in_screen.dart').readAsStringSync();
      final signUp = File('lib/auth/screens/sign_up_screen.dart').readAsStringSync();
      expect(signIn, contains("import 'package:go_router/go_router.dart'"));
      expect(signUp, contains("import 'package:go_router/go_router.dart'"));
      expect(signIn, isNot(contains('pushReplacementNamed')));
      expect(signUp, isNot(contains('pushReplacementNamed')));
      expect(signIn, contains('context.go('));
      expect(signUp, contains('context.go('));
    });

    test('C23-2: reliance provider fails closed on server error — SocketException/TimeoutException only for offline fallback', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      expect(provider, contains("import 'dart:io'"));
      expect(provider, contains("import 'dart:async'"));
      expect(provider, contains('SocketException'));
      expect(provider, contains('TimeoutException'));
      expect(provider, contains('B delta'));
      expect(provider, isNot(contains('} catch (_) {\n        // Fallback to local receipt on server failure')));
    });

    test('C24-1: Step 2 evidence upload surfaces SHA-256 binding and auto-claim-credit prohibition', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('SHA-256'));
      expect(submit, contains('governs evidence credit independently'));
    });

    test('C24-2: Step 6 confirmation back button routes to /my-pv not /home', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains("context.go('/home')")));
      expect(submit, contains("context.go('/my-pv')"));
    });

    test('C24-3: Step 4 determination result has retry path when quote is unavailable', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('onRetry'));
      expect(submit, contains('_refetchQuote'));
    });

    test('C24-4: Step 4 surfaces T4 Gold Seal separation notice for T4 tier', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains("q.tier == 'T4'"));
      expect(submit, contains('separate authority chain'));
    });

    test('C25-1: SubmissionDetailScreen AppBar back uses go_router — no Navigator.of(context).pop()', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains("import 'package:go_router/go_router.dart'"));
      expect(detail, isNot(contains('Navigator.of(context).pop()')));
      expect(detail, contains('context.pop()'));
    });

    test('C25-2: ActivityScreen row tap uses go_router — no MaterialPageRoute or Navigator.push', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, contains("import 'package:go_router/go_router.dart'"));
      expect(activity, isNot(contains('Navigator.of(context).push(')));
      expect(activity, isNot(contains('MaterialPageRoute(')));
      expect(activity, contains('context.push('));
      expect(activity, contains("'/activity/\${items[i].submissionId}'"));
    });

    test('C25-3: App router registers /activity/:submissionId route — SubmissionDetailScreen reachable via URL', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      expect(router, contains("import '../../activity/screens/submission_detail_screen.dart'"));
      expect(router, contains("name: 'submission-detail'"));
      expect(router, contains("pathParameters['submissionId']"));
    });

    test('C28-1: publicId alone must not unlock a public-reliance Verify action — R32: payment gate removed, CROSS_LANE_HANDOFF_REQUIRED', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      expect(detail, isNot(contains('settlementData!.isSettled')));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
    });

    test('C28-2: payment state alone does not unlock public-reliance Verify — R32: gate removed entirely, CROSS_LANE_HANDOFF_REQUIRED', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('_SettlementStatusSection'));
      expect(detail, contains('_MyPvNavigationSection'));
      expect(detail, isNot(contains('settlementData!.isSettled')));
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    test('C28-3: settlement CTA wired in R29 — hasSettlementSeam gate replaces null-ambiguous suppression', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('detail.settlementPaymentStatus == null')));
      expect(detail, contains('detail.hasSettlementSeam'));
      expect(detail, contains('class _SettlementCtaSection'));
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
    });

    test('C28-4: unknown/error settlement state must not enable settlement CTA — R29 gate requires hasSettlementSeam+null data', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('SettlementPaymentStatus.unknown'));
      expect(detail, contains('class _SettlementCtaSection'));
      expect(detail, contains('detail.hasSettlementSeam'));
      expect(detail, contains('detail.settlementData == null'));
    });

    test('C28-5: public record authority must not use isSettled — R32: gate removed, CROSS_LANE_HANDOFF_REQUIRED', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(model, isNot(contains("'registry_active'")));
      expect(model, isNot(contains('registryActive')));
      expect(detail, isNot(contains("'registry_active'")));
      expect(detail, isNot(contains('registryActive')));
      expect(detail, isNot(contains('settlementData!.isSettled')));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    test('C29-1: Settlement model: isSettled = FREE or PAID; class decoded from data.settlement', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('class Settlement'));
      expect(model, contains("'FREE'"));
      expect(model, contains("'PAID'"));
      expect(model, contains('isSettled'));
      expect(model, contains('paymentStatus'));
      expect(model, contains('orderId'));
      expect(model, contains('MONEY_CONTROLS_TRUST = FALSE'));
    });

    test('C29-2: hasSettlementSeam uses json.containsKey — key-absent old API is fail-closed', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains("json.containsKey('settlement')"));
      expect(model, contains('hasSettlementSeam'));
    });

    test('C29-3: _ProvenanceRecordAction removed in R32 — isSettled gate gone, CROSS_LANE_HANDOFF_REQUIRED active', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      expect(detail, contains('_ProvenanceRecordAction removed in R32'));
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      expect(detail, isNot(contains('settlementData!.isSettled')));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    test('C29-4: Settlement CTA shown when hasSettlementSeam + no order linked + determination present', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('detail.hasSettlementSeam'));
      expect(detail, contains('detail.settlementData == null'));
      expect(detail, contains('detail.determination != null'));
      expect(detail, contains('_SettlementCtaSection(submissionId: detail.submissionId)'));
    });

    test('C29-5: SubmissionDetail.fromJson reads settlement key safely — key-absent and key-present-null both handled', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains("json.containsKey('settlement')"));
      expect(model, contains("json['settlement'] is Map<String, dynamic>"));
      expect(model, contains('hasSettlementSeam:'));
      expect(model, contains('settlementData:'));
    });

    test('C30-1: CredentialLifecycleStatus enum present with all six values and displayLabel', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('enum CredentialLifecycleStatus'));
      expect(model, contains('active'));
      expect(model, contains('suspended'));
      expect(model, contains('revoked'));
      expect(model, contains('expired'));
      expect(model, contains('superseded'));
      expect(model, contains('notIssued'));
      expect(model, contains('displayLabel'));
    });

    test('C30-2: fromApiString is null-safe and fail-closed — null → null, NOT_ISSUED maps explicitly', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('if (raw == null) return null'));
      expect(model, contains("case 'NOT_ISSUED'"));
      expect(model, contains('return CredentialLifecycleStatus.notIssued'));
    });

    test('C30-3: REGISTRY_STATE_ONLY annotation present — lifecycle plane separate from trust and settlement', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('REGISTRY_STATE_ONLY = TRUE'));
    });

    test('C30-4: SubmissionDetail.credentialLifecycle field decoded from credential_lifecycle JSON key', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('credentialLifecycle'));
      expect(model, contains("json['credential_lifecycle']"));
      expect(model, contains('CredentialLifecycleStatus.fromApiString'));
    });

    test('C30-5: _CredentialLifecycleSection widget present; shown only when credentialLifecycle non-null', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('_CredentialLifecycleSection'));
      expect(detail, contains('detail.credentialLifecycle != null'));
      expect(detail, contains('status: detail.credentialLifecycle!'));
    });

    test('C31-1: StaleBanner surfaces approachingStale advisory before requiresRequery gate', () {
      final banner = File('lib/trust/widgets/stale_banner.dart').readAsStringSync();
      expect(banner, contains('approachingStale'));
      expect(banner, contains('Verification due soon'));
      expect(banner, contains('_ApproachingStaleAdvisory'));
    });

    test('C31-2: _CredentialLifecycleSection shows revoked do-not-rely advisory', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('Do not rely on this record'));
      expect(detail, contains('revoked'));
    });

    test('C31-3: _CredentialLifecycleSection shows suspended verify-before-relying advisory', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('suspended'));
      expect(detail, contains('verify current status before relying'));
    });

    test('C31-4: _CredentialLifecycleSection is lifecycle-aware with distinct states', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('_LifecycleStyle'));
      expect(detail, contains('CredentialLifecycleStatus.active'));
      expect(detail, contains('PvColors.success'));
      expect(detail, contains('PvColors.error'));
    });

    test('C31-5: REGISTRY_STATE_ONLY annotation and NOT_ISSUED preserved in enhanced section', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('REGISTRY_STATE_ONLY = TRUE'));
      expect(detail, contains('NOT_ISSUED'));
    });

    test('C32-1: SettlementPaymentStatus.lookupError is distinct — not collapsed to unknown', () {
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('lookupError'));
      expect(models, contains('LOOKUP_ERROR'));
      expect(models, contains('Settlement Unavailable'));
    });

    test('C32-2: payment-gated Public Verify removed — CROSS_LANE_HANDOFF_REQUIRED annotated', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('payment-gated authority removed'));
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
      expect(detail, contains('MONEY_CONTROLS_TRUST = FALSE'));
    });

    test('C32-3: authorityUnavailable does not downgrade to neutral — fail-closed in model and UI', () {
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('authorityUnavailable'));
      expect(models, contains('CREDENTIAL_AUTHORITY_UNAVAILABLE'));
      expect(models, contains('REGISTRY_AUTHORITY_UNAVAILABLE'));
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('authorityUnavailable'));
      expect(detail, contains('authority unavailable'));
    });

    test('C32-4: TrustCurrentness model consumes all PR47 currentness fields', () {
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('TrustCurrentness'));
      expect(models, contains('determination_state'));
      expect(models, contains('determination_is_current'));
      expect(models, contains('requery_guidance'));
      expect(models, contains('reliance_boundary'));
      expect(models, contains('authority_note'));
      expect(models, contains('credential_state'));
    });

    test('C32-5: LOOKUP_ERROR settlement gate excludes CTA — no CTA on authority failure', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, contains('_SettlementLookupErrorSection'));
      expect(detail, contains('SETTLEMENT UNAVAILABLE'));
      expect(detail, contains('SettlementPaymentStatus.lookupError'));
    });

    test('C33-1: list credential_state placeholder NOT displayed as badge — Core PR48 authority ruling', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(screen, isNot(contains('item.credentialState!.toUpperCase()')));
      expect(screen, isNot(contains('item.credentialState!.isNotEmpty')));
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('credentialState'));
      expect(models, contains('credential_state'));
    });

    test('C33-2: AUTHORITY_UNAVAILABLE list card — error border + badge; tier suppressed', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(screen, contains("determinationState == 'AUTHORITY_UNAVAILABLE'"));
      expect(screen, contains('PvColors.error'));
      expect(screen, contains('AUTHORITY UNAVAILABLE'));
      final avIdx = screen.indexOf("determinationState == 'AUTHORITY_UNAVAILABLE'");
      final tierIdx = screen.indexOf('determinedTier != null');
      expect(avIdx, lessThan(tierIdx),
          reason: 'AUTHORITY_UNAVAILABLE branch must precede tier display — tier suppressed when authority unavailable');
    });

    test('C33-3: AUTHORITY_UNAVAILABLE list card — notice paragraph shown', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(screen, contains('Canonical determination temporarily unavailable'));
      expect(screen, contains('View details or refresh to retry'));
    });

    test('C33-4: no payment/settlement inference for credential on list card — MTA-1 enforced', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(screen, isNot(contains('settlementPaymentStatus')));
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('MTA-1: SERVER DETERMINES TRUST'));
      expect(models, contains('MONEY_CONTROLS_TRUST = FALSE'));
    });

    test('C34-1: fromApiString default fails closed to authorityUnavailable — not notIssued', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('return CredentialLifecycleStatus.authorityUnavailable'));
      final defaultIdx = model.indexOf('default:');
      expect(defaultIdx, greaterThan(0));
      final defaultArm = model.substring(defaultIdx, defaultIdx + 80);
      expect(defaultArm, contains('authorityUnavailable'));
    });

    test('C34-2: credential lifecycle source annotation references pv_credentials — not pv_review_cases', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains('pv_credentials'));
      expect(model, isNot(contains('pv_review_cases')));
    });

    test('C42-1: local receipt built with unknown validity — never valid', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      expect(provider, contains('validityState: ReceiptValidityState.unknown'));
      expect(provider, isNot(contains('validityState: ReceiptValidityState.valid,\n    policyVersion: policyVersion,\n    isServerIssued: false')));
    });

    test('C42-2: receipt list distinguishes local snapshot badge — no green VALID for isServerIssued=false', () {
      final list = File('lib/reliance/screens/receipt_list_screen.dart').readAsStringSync();
      expect(list, contains("'LOCAL SNAPSHOT'"));
      expect(list, contains('isServerIssued'));
      expect(list, isNot(contains('receipt.validityState.name.toUpperCase()')));
    });

    test('C42-3: receipt detail shows authority warning and requery for local snapshot', () {
      final detail = File('lib/reliance/screens/receipt_detail_screen.dart').readAsStringSync();
      expect(detail, contains('isServerIssued'));
      expect(detail, contains('LOCAL SNAPSHOT'));
      expect(detail, contains("reliance'"));
      expect(detail, contains("'/verify'"));
    });

    test('C42-4: reliance screen save confirmation distinguishes local vs server receipt', () {
      final screen = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      expect(screen, contains('isServerIssued'));
      expect(screen, contains('not current authority'));
    });

    test('C42-5: server-issued receipt validityState remains valid — only local changed', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      expect(provider, contains('validityState: ReceiptValidityState.valid'));
      expect(provider, contains('isServerIssued: true'));
    });

    test('C42-6: SocketException/TimeoutException fallback still fails closed on ApiException — B delta preserved', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      expect(provider, contains('B delta'));
      expect(provider, contains('on SocketException catch'));
      expect(provider, contains('on TimeoutException catch'));
      expect(provider, isNot(contains('} catch (e) {\n        receipt = _buildLocalReceipt')));
      expect(provider, isNot(contains('} catch (_) {\n        receipt = _buildLocalReceipt')));
    });

    test('C44-1: _AssetCard derives effectiveTier from eligible before display', () {
      final screen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      expect(screen, contains('_effectiveTier()'));
      expect(screen, contains('asset.eligible ? asset.trustTier : null'));
      expect(screen, isNot(contains('_tierLabel(asset.trustTier)')));
      expect(screen, contains('_tierColor(effectiveTier)'));
      expect(screen, contains('_tierLabel(effectiveTier)'));
    });

    test('C44-2: list and detail agree — ineligible shows NOT QUALIFIED on both', () {
      final listScreen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      final detailScreen = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(listScreen, contains("if (tier == null) return 'NOT QUALIFIED'"));
      expect(detailScreen, contains("if (!asset.eligible) return 'NOT QUALIFIED'"));
    });

    test('C44-3: evidence section wording does not claim verification authority for server-recorded items', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('provided by the verification authority')));
      expect(detail, contains('recorded on submission'));
      expect(detail, contains('No inferences beyond what is explicitly stated'));
      expect(detail, contains('does not make an item independent'));
    });

    test('C44-4: integrity wording is file-integrity-only — not independent evidentiary verification', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, contains('File integrity verified'));
      expect(detail, isNot(contains("'Integrity verified'")));
    });

    test('C44-5: no Transfer mutation or Professional-mode route/action introduced', () {
      final myPvScreen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      final detailScreen = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(myPvScreen, isNot(contains('/transfer')));
      expect(detailScreen, isNot(contains('/transfer')));
      expect(myPvScreen, isNot(contains('/professional')));
      expect(detailScreen, isNot(contains('/professional')));
      expect(detailScreen, contains('Verify Now'));
      expect(detailScreen, contains('Submit Update'));
      expect(detailScreen, isNot(contains('Transfer')));
    });

    test('C45-proof-1: non-autoDispose FutureProvider.family retains result across consumer teardown', () async {
      var callCount = 0;
      final nonDisposeProvider = FutureProvider.family<String, String>((ref, arg) async {
        callCount++;
        return 'result-$arg';
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub1 = container.listen(nonDisposeProvider('key'), (_, __) {});
      await container.read(nonDisposeProvider('key').future);
      expect(callCount, 1);

      sub1.close();

      final sub2 = container.listen(nonDisposeProvider('key'), (_, __) {});
      await container.read(nonDisposeProvider('key').future);
      expect(callCount, 1,
          reason: 'Non-autoDispose served retained result to new consumer — this is the defect');
      sub2.close();
    });

    test('C45-proof-2: autoDispose FutureProvider.family forces fresh evaluation after consumer teardown', () async {
      var callCount = 0;
      var disposeCount = 0;
      final autoDisposeProvider = FutureProvider.autoDispose.family<String, String>((ref, arg) async {
        callCount++;
        ref.onDispose(() { disposeCount++; });
        return 'result-$arg';
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub1 = container.listen(autoDisposeProvider('key'), (_, __) {});
      await container.read(autoDisposeProvider('key').future);
      expect(callCount, 1);
      expect(disposeCount, 0, reason: 'Provider not yet disposed — listener still active');

      sub1.close();
      await Future<void>.delayed(Duration.zero);
      expect(disposeCount, 1, reason: 'onDispose ran — provider was actually disposed after all listeners removed');

      final sub2 = container.listen(autoDisposeProvider('key'), (_, __) {});
      await container.read(autoDisposeProvider('key').future);
      expect(callCount, 2,
          reason: 'AutoDispose made fresh evaluation on new consumer after disposal');
      sub2.close();
    });

    test('C45-1: simpleActionabilityProvider is declared autoDispose — no retained actionability for reliance', () {
      final source = File('lib/actionability/providers/actionability_provider.dart').readAsStringSync();
      expect(source, contains('simpleActionabilityProvider = FutureProvider.autoDispose.family'));
      expect(source, contains('actionabilityProvider = FutureProvider.autoDispose.family'));
      expect(source, isNot(contains('= FutureProvider.family<ActionabilityResult,')));
    });

    test('C45-2: actionabilityProvider (full-args variant) is also autoDispose', () {
      final provider = File('lib/actionability/providers/actionability_provider.dart').readAsStringSync();
      final autoDisposeCount = 'FutureProvider.autoDispose.family'.allMatches(provider).length;
      expect(autoDisposeCount, greaterThanOrEqualTo(2),
          reason: 'Both actionabilityProvider and simpleActionabilityProvider must be autoDispose');
      expect(provider, isNot(contains('= FutureProvider.family')));
    });

    test('C45-3: trustRecordProvider is declared autoDispose — no retained trust record for verify', () {
      final provider = File('lib/trust/providers/trust_provider.dart').readAsStringSync();
      expect(provider, contains('FutureProvider.autoDispose.family<TrustRecord'));
      expect(provider, isNot(contains('FutureProvider.family<TrustRecord')));
      expect(provider, contains('autoDispose'));
    });

    test('C45-4: RelianceScreen no-cache assertion preserved and aligned with autoDispose enforcement', () {
      final screen = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      expect(screen, contains('actionabilityCacheForReliance'));
      expect(screen, contains('Actionability must not be cached for reliance'));
    });

    test('C45-5: receipt B-delta preserved — SocketException/TimeoutException only; ApiException propagates', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      expect(provider, contains('on SocketException catch'));
      expect(provider, contains('on TimeoutException catch'));
      expect(provider, isNot(contains('} catch (e) {\n        receipt = _buildLocalReceipt')));
      expect(provider, isNot(contains('} catch (_) {\n        receipt = _buildLocalReceipt')));
    });

    test('C35-1: my_pv tier labels use canonical Web/Core names — not abbreviated variants', () {
      final screen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      expect(screen, contains('Accountable Existence'));
      expect(screen, contains('Accountable Declaration'));
      expect(screen, contains('Evidence-Established Trust'));
      expect(screen, contains('Highest Governed Provenance Authority'));
      expect(screen, isNot(contains("'T1 EXISTENCE'")));
      expect(screen, isNot(contains("'T2 DECLARATION'")));
      expect(screen, isNot(contains("'T3 EVIDENCE-ESTABLISHED'")));
      expect(screen, isNot(contains("'T4 GOVERNED AUTHORITY'")));
    });

    test('C46-1: submit_screen imports image_picker and file_picker — native packages wired', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(screen, contains("import 'package:image_picker/image_picker.dart'"));
      expect(screen, contains("import 'package:file_picker/file_picker.dart'"));
      expect(screen, contains("import 'dart:io'"));
    });

    test('C46-2: _PhotoSection calls ImagePicker.pickImage with gallery source — no SnackBar stub', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(screen, contains('ImagePicker()'));
      expect(screen, contains('pickImage(source: ImageSource.gallery'));
      expect(screen, contains('addPhoto(picked.path)'));
      expect(screen, isNot(contains("'Photo upload not yet implemented'")));
    });

    test('C46-3: _PhotoTile renders Image.file — not icon placeholder', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(screen, contains('Image.file('));
      expect(screen, contains('File(path)'));
      expect(screen, contains('errorBuilder:'));
      expect(screen, contains('broken_image'));
    });

    test('C46-4: Step 2 document section calls FilePicker.platform.pickFiles — no SnackBar stub', () {
      final screen = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(screen, contains('FilePicker.platform.pickFiles('));
      expect(screen, contains('result.files.isNotEmpty'));
      expect(screen, contains('addDocument(EvidenceDocument('));
      expect(screen, isNot(contains("'File upload not yet implemented'")));
    });

    test('C46-5: file_picker version is >=8.1.4 — compileSdk 36 in plugin build.gradle (AAR parity fix)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('file_picker: ^8.1.4'));
      expect(pubspec, isNot(contains('file_picker: ^8.1.2')));
      expect(pubspec, isNot(contains('file_picker: ^8.0')));
      expect(pubspec, isNot(contains('file_picker: ^7.')));
    });

    test('C47-1: Share is server-gated — Clipboard.setData present only under publicRecordUrl guard', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, contains('Clipboard.setData'));
      expect(detail, contains('publicRecordUrl'));
      expect(detail, contains('final url = publicRecordUrl'));
      expect(detail, contains('url != null && url.isNotEmpty'));
      expect(detail, isNot(contains('Env.pvApiBaseUrl}/verify/')));
      expect(detail, isNot(contains("'Share coming soon'")));
    });

    test('C47-2: Share wired from server-authored URL — trust provider seam present in detail screen', () {
      final detail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(detail, contains("import 'package:flutter/services.dart'"));
      expect(detail, contains("import '../../trust/providers/trust_provider.dart'"));
      expect(detail, contains('trustRecordProvider'));
      expect(detail, contains('public_record_url'));
      expect(detail, isNot(contains('CROSS_LANE_HANDOFF_REQUIRED')));
    });

    test('C48-1: AndroidManifest declares no broad-media storage permissions — system picker boundary', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
      expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
      expect(manifest, contains('android.permission.CAMERA'));
    });

    test('C48-2: gradle.afterProject upgrades compileSdk to 36 — upgrade-only guard present', () {
      final gradle = File('android/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('gradle.afterProject'));
      expect(gradle, contains('< 36'));
      expect(gradle, contains('"com.android.library"'));
    });

    test('C50-1: submit wizard has exactly 7 steps (0-6) and all step widget classes defined', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('_kTotalSteps = 7'));
      expect(submit, contains('class _Step0TrustLadder'));
      expect(submit, contains('class _Step1AssetInfo'));
      expect(submit, contains('class _Step2Evidence'));
      expect(submit, contains('class _Step3Declarations'));
      expect(submit, contains('class _Step4DeterminationPricing'));
      expect(submit, contains('class _Step5Settlement'));
      expect(submit, contains('class _Step6Confirmation'));
    });

    test('C50-2: determination (Step 4) precedes settlement (Step 5) in _buildStep — determination-first enforced', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      final det4Idx = submit.indexOf('_Step4DeterminationPricing');
      final set5Idx = submit.indexOf('_Step5Settlement');
      expect(det4Idx, isNot(-1), reason: '_Step4DeterminationPricing must be present in _buildStep');
      expect(set5Idx, isNot(-1), reason: '_Step5Settlement must be present in _buildStep');
      expect(det4Idx, lessThan(set5Idx), reason: 'determination step must precede settlement step — determination-first enforced');
    });

    test('C50-3: ActivitySubmission.determinedTier is server-authoritative — CUSTOMER_SELECTS_TIER=FALSE annotated', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(model, contains("json['determined_tier']"));
      expect(model, contains('determinedTier'));
      expect(model, contains('CUSTOMER_SELECTS_TIER'));
    });

    test('C50-4: submit_provider wires physical evidence upload via uploadPendingDocuments and uploadEvidence', () {
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, contains('uploadPendingDocuments'));
      expect(provider, contains('uploadEvidence'));
      expect(provider, contains('!doc.uploaded'));
    });

    test('C50-5: home_screen watches homeAlertsProvider — alerts are server-sourced, not a static list', () {
      final home = File('lib/home/screens/home_screen.dart').readAsStringSync();
      expect(home, contains('homeAlertsProvider'));
      expect(home, contains('ref.watch(homeAlertsProvider)'));
      expect(home, contains('.when('));
    });

    test('C50-6: photo picker (_PhotoSection) wraps pickImage in try/catch — PlatformException fail-safe', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('picker.pickImage'));
      final pickIdx = submit.indexOf('picker.pickImage');
      final catchIdx = submit.indexOf('} catch (_) {', pickIdx);
      expect(pickIdx, isNot(-1), reason: 'pickImage call must be present');
      expect(catchIdx, isNot(-1), reason: 'catch block must follow pickImage');
      expect(submit, contains('Could not access photo library. Please try again.'));
    });

    test('C50-7: file picker (_Step2Evidence) wraps pickFiles in try/catch — PlatformException fail-safe', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('FilePicker.platform.pickFiles'));
      final pickIdx = submit.indexOf('FilePicker.platform.pickFiles');
      final catchIdx = submit.indexOf('} catch (_) {', pickIdx);
      expect(pickIdx, isNot(-1), reason: 'pickFiles call must be present');
      expect(catchIdx, isNot(-1), reason: 'catch block must follow pickFiles');
      expect(submit, contains('Could not access files. Please try again.'));
    });

    test('C50-8: MachineTrustResponse parses public_record_url — server-authored Share seam', () {
      final mtr = File('lib/trust/machine_trust_response.dart').readAsStringSync();
      expect(mtr, contains('publicRecordUrl'));
      expect(mtr, contains("j['public_record_url']"));
      expect(mtr, contains('String? publicRecordUrl'));
      expect(mtr, contains('publicRecordUrl: publicRecordUrl'));
    });

    test('C50-9: CUSTODY_IS_NOT_LEGAL_TITLE=TRUE annotated on TrustRecord.continuity — display-only guard', () {
      final models = File('lib/trust/trust_models.dart').readAsStringSync();
      expect(models, contains('CUSTODY_IS_NOT_LEGAL_TITLE'));
      expect(models, contains('TrustContinuity? continuity'));
      expect(models, contains('display-only'));
    });

    test('C50-10: MachineTrustResponse parses purchase.qualification_outcome — MONEY_CONTROLS_TRUST=FALSE', () {
      final mtr = File('lib/trust/machine_trust_response.dart').readAsStringSync();
      expect(mtr, contains('purchaseQualificationOutcome'));
      expect(mtr, contains("purchase['qualification_outcome']"));
      expect(mtr, contains('String? purchaseQualificationOutcome'));
      expect(mtr, contains('MONEY_CONTROLS_TRUST'));
    });

    test('C50-11: picker cancel (null return) — no error SnackBar shown, no crash', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('if (picked != null)'));
      final nullIdx = submit.indexOf('if (picked != null)');
      final addIdx  = submit.indexOf('addPhoto(picked.path)');
      expect(nullIdx, isNot(-1), reason: 'null guard for cancel path must be present');
      expect(addIdx,  isNot(-1), reason: 'addPhoto must be guarded by null check');
      expect(addIdx, greaterThan(nullIdx),
          reason: 'addPhoto must be inside the null guard — cancel does not call addPhoto');
      expect(submit, contains('if (result != null && result.files.isNotEmpty)'));
    });

    test('C50-12: upload failure — uploadPendingDocuments SubmitApiException surfaces as error banner', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('uploadPendingDocuments()'));
      expect(submit, contains('on SubmitApiException catch (e)'));
      expect(submit, contains('_setError('));
      expect(submit, contains("'Server error (\${e.statusCode}): \${e.message}'"));
      expect(submit, contains('_ErrorBanner'));
      expect(submit, contains('if (_error != null)'));
    });

    test('C50-13: backend unavailable — submitForEvaluation/fetchQuote failures surface as error; 401 redirects to sign-in', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, contains('submitForEvaluation()'));
      expect(submit, contains('fetchQuote()'));
      expect(submit, contains('on SubmitApiException catch (e)'));
      expect(submit, contains('e.statusCode == 401'));
      expect(submit, contains("context.push('/sign-in"));
      expect(submit, contains("'Server error (\${e.statusCode}): \${e.message}'"));
      expect(submit, contains("'An unexpected error occurred. Please try again.'"));
    });

    test('C50-14: evidence persistence — photoPaths and documents survive step navigation', () {
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, contains('copyWith(step: step)'));
      expect(provider, contains('photoPaths: [...c.photoPaths, path]'));
      expect(provider, contains('documents: [...c.documents, doc]'));
      expect(provider, contains('markDocumentUploaded'));
      final goToIdx = provider.indexOf('void goToStep(');
      expect(goToIdx, isNot(-1), reason: 'goToStep must be present');
      final goToEnd = provider.indexOf('}', goToIdx);
      final goToBody = provider.substring(goToIdx, goToEnd);
      expect(goToBody, contains('copyWith'), reason: 'goToStep must use copyWith, not reset');
      expect(goToBody, isNot(contains('reset()')), reason: 'goToStep must not reset state');
    });

    test('C50-15: retry/idempotency — uploadPendingDocuments skips already-uploaded documents; safe to re-enter', () {
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, contains('!doc.uploaded'));
      expect(provider, contains('markDocumentUploaded(i)'));
      expect(provider, contains('Future<void> uploadPendingDocuments()'));
      expect(provider, contains('for (int i = 0; i < current.documents.length; i++)'));
    });

    test('C51-1: Defect D repair — lifecycleWarning (SUPERSEDED/EXPIRED) disables Save Receipt; fresh requery required before reliance', () {
      final screen = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      expect(screen, contains('lifecycleWarning'));
      expect(screen, contains("lifecycleStatus == 'EXPIRED' || lifecycleStatus == 'SUPERSEDED'"),
          reason: 'lifecycleWarning must cover both EXPIRED and SUPERSEDED — not silently treated as current');
      expect(screen, contains('lifecycleBlocked || lifecycleWarning'),
          reason: 'SUPERSEDED/EXPIRED must gate Save Receipt — Defect D repair: cannot produce receipt without requery');
    });

    test('C51-2: Defect D repair — Requery in lifecycle warning section invalidates both trustRecordProvider and simpleActionabilityProvider', () {
      final screen = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      final warningIdx = screen.indexOf('lifecycleWarning)');
      expect(warningIdx, isNot(-1), reason: 'lifecycleWarning branch must be present');
      final branchEnd = screen.indexOf('DropdownButtonFormField', warningIdx);
      expect(branchEnd, isNot(-1), reason: 'DropdownButtonFormField must follow the lifecycleWarning branch');
      final warningSection = screen.substring(warningIdx, branchEnd);
      expect(warningSection, contains('ref.invalidate(trustRecordProvider('),
          reason: 'Requery must force fresh trust server evaluation for lifecycle currency');
      expect(warningSection, contains('ref.invalidate(simpleActionabilityProvider('),
          reason: 'Requery must force fresh actionability evaluation synchronized with trust');
      expect(warningSection, contains('Requery for Current Status'),
          reason: 'Requery button must be present and labeled in lifecycle warning section');
    });

    test('C51-3: Share invariant — Clipboard copies server-authored URL only; no publicId or Env.pvApiBaseUrl synthesis', () {
      final screen = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(screen, contains('publicRecordUrl'));
      expect(screen, contains('final url = publicRecordUrl'));
      expect(screen, contains('Clipboard.setData'));
      expect(screen, isNot(contains('Env.pvApiBaseUrl')),
          reason: 'Share must not synthesize URL from PV_API_BASE_URL — server-authored url only');
      final clipIdx = screen.indexOf('Clipboard.setData');
      final urlGuardIdx = screen.indexOf('if (url != null && url.isNotEmpty)');
      expect(urlGuardIdx, isNot(-1), reason: 'publicRecordUrl null+empty guard must be present');
      expect(clipIdx, greaterThan(urlGuardIdx),
          reason: 'Clipboard.setData must be inside the publicRecordUrl guard — missing URL = no Share');
    });

    test('C51-4: _LifecycleBanner in trust_result_screen is visually and semantically explicit for REVOKED, SUSPENDED, SUPERSEDED, EXPIRED', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(screen, contains("'SUSPENDED'"));
      expect(screen, contains("'REVOKED'"));
      expect(screen, contains("'SUPERSEDED'"));
      expect(screen, contains("'EXPIRED'"));
      expect(screen, contains('Do not rely on this record'));
      expect(screen, contains('Verify currency before reliance'));
      final bannerIdx = screen.indexOf('_LifecycleBanner');
      final actionsIdx = screen.indexOf('_ActionButtons');
      expect(bannerIdx, isNot(-1), reason: '_LifecycleBanner must be a distinct component');
      expect(actionsIdx, isNot(-1), reason: '_ActionButtons must be present');
      expect(bannerIdx, lessThan(actionsIdx),
          reason: 'Lifecycle banner must appear before action buttons — user sees lifecycle state before CTA');
      expect(screen, contains('Semantics('));
    });

    test('C51-5: reliance_screen lifecycle gate — REVOKED + SUSPENDED + SUPERSEDED + EXPIRED + UNKNOWN all prevent receipt production', () {
      final screen = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      expect(screen, contains("const blockedLifecycles = {'REVOKED', 'SUSPENDED'}"));
      expect(screen, contains('lifecycleBlocked'));
      expect(screen, contains("lifecycleStatus == 'EXPIRED' || lifecycleStatus == 'SUPERSEDED'"));
      expect(screen, contains('lifecycleWarning'));
      expect(screen, contains('isUnknown || _saving || lifecycleBlocked || lifecycleWarning'),
          reason: 'All dangerous lifecycle states must disable Save Receipt');
      expect(screen, contains("'RELIANCE BLOCKED — This record is \$lifecycleStatus. '"));
      expect(screen, contains('Requery for Current Status'));
      expect(screen, contains('UNKNOWN actionability — Do not rely on this record for the stated purpose'));
    });
  });

  // ---------------------------------------------------------------------------
  // M2-50-08 — Physical-object matching gate
  // PHYSICAL_MATCH_NOT_SUPPORTED: no approved physical proof method is operational.
  // ---------------------------------------------------------------------------
  group('M2-50-08 Physical Match Gate (C52)', () {
    test('C52-1: trust_result_screen has explicit physical match capability gate with correct text', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(screen, contains('_PhysicalMatchGate'));
      expect(screen, contains('Physical object matching: not available'));
      expect(screen, contains('no approved physical proof method is operational'));
      final recordViewIdx = screen.indexOf('class _RecordView');
      final gateIdx = screen.indexOf('_PhysicalMatchGate()', recordViewIdx);
      final actionsIdx = screen.indexOf('_ActionButtons', recordViewIdx);
      expect(gateIdx, isNot(-1), reason: '_PhysicalMatchGate() must be instantiated in _RecordView');
      expect(actionsIdx, isNot(-1), reason: '_ActionButtons must be present in _RecordView');
      expect(gateIdx, lessThan(actionsIdx),
          reason: 'Physical match gate must appear before action buttons');
      expect(screen, contains('Semantics('));
      expect(screen, contains('PHYSICAL_MATCH_NOT_SUPPORTED'));
    });

    test('C52-2: trust_result_screen does not display SubjectMatchState as a user-facing match claim', () {
      final screen = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      expect(screen, isNot(contains('subjectMatchState')),
          reason: 'SubjectMatchState is a server field only — not displayed in trust result screen');
      expect(screen, isNot(contains('CONFIRMED_MATCH')),
          reason: 'No physical match claims in UI — physical matching is not supported');
      expect(screen, isNot(contains('PROBABLE_MATCH')),
          reason: 'No physical match claims in UI — physical matching is not supported');
    });
  });

  // ---------------------------------------------------------------------------
  // M2-50-07 — Professional inventory/batch tools
  // PROFESSIONAL_CANNOT_SELECT_TIER — projects canonical trust and commercial
  // eligibility only. Tier is server-determined. Batch fails closed.
  // ---------------------------------------------------------------------------
  group('M2-50-07 Professional Batch (C53)', () {
    test('C53-1: professional_batch_screen exists and contains no tier-selection UI', () {
      final screen = File('lib/professional/screens/professional_batch_screen.dart').readAsStringSync();
      expect(screen.isNotEmpty, isTrue, reason: 'professional_batch_screen.dart must exist');
      expect(screen, contains('PROFESSIONAL_CANNOT_SELECT_TIER'));
      expect(screen, isNot(contains('selectTier')),
          reason: 'Professional mode cannot select tier');
      expect(screen, isNot(contains('tier: \'')),
          reason: 'No hardcoded tier string assertions — tier is server-determined');
      expect(screen, isNot(contains('DropdownButton<int>')),
          reason: 'No tier dropdown in professional mode');
    });

    test('C53-2: professional_batch_screen fails closed — AUTHORITY UNAVAILABLE text present', () {
      final screen = File('lib/professional/screens/professional_batch_screen.dart').readAsStringSync();
      expect(screen, contains('AUTHORITY UNAVAILABLE'),
          reason: 'Batch screen must show AUTHORITY UNAVAILABLE for unqualified/unknown records');
      expect(screen, contains('safeTier'),
          reason: 'Professional batch must use safeTier to fail closed on UNQUALIFIED');
      expect(screen, contains('_UnavailableRow'),
          reason: '_UnavailableRow must handle both UNQUALIFIED and query failure cases');
    });

    test('C53-3: professional_batch_screen surfaces purchaseQualificationOutcome', () {
      final screen = File('lib/professional/screens/professional_batch_screen.dart').readAsStringSync();
      expect(screen, contains('purchaseQualificationOutcome'),
          reason: 'Server-authored purchaseQualificationOutcome must be displayed');
      expect(screen, contains('Commercial eligibility'),
          reason: 'purchaseQualificationOutcome must be labeled as commercial eligibility');
      expect(screen, contains('MONEY_CONTROLS_TRUST = FALSE'),
          reason: 'Professional batch must annotate that money does not control trust');
    });

    test('C53-4: professional route is auth-gated and entry point is in scanner only', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      final scanner = File('lib/scanner/screens/scanner_screen.dart').readAsStringSync();
      expect(router, contains("'/professional'"),
          reason: '/professional must be in _protectedPrefixes');
      expect(scanner, contains('/professional/batch'),
          reason: 'scanner_screen must provide professional batch entry point');
      final myPv = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      final assetDetail = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      expect(myPv, isNot(contains('/professional')),
          reason: 'my_pv_screen must not reference /professional (C44-5)');
      expect(assetDetail, isNot(contains('/professional')),
          reason: 'asset_detail_screen must not reference /professional (C44-5)');
    });
  });

  group('M2-50-07 Professional Inventory (C54)', () {
    test('C54-1: professional_inventory_screen exists with PROFESSIONAL_CANNOT_SELECT_TIER annotation', () {
      final screen = File('lib/professional/screens/professional_inventory_screen.dart').readAsStringSync();
      expect(screen.isNotEmpty, isTrue,
          reason: 'professional_inventory_screen.dart must exist');
      expect(screen, contains('PROFESSIONAL_CANNOT_SELECT_TIER'),
          reason: 'Inventory must annotate PROFESSIONAL_CANNOT_SELECT_TIER — no tier selection');
      expect(screen, contains('MONEY_CONTROLS_TRUST = FALSE'),
          reason: 'Inventory must annotate that money does not control trust');
    });

    test('C54-2: professional_inventory_screen fails closed — AUTHORITY UNAVAILABLE present', () {
      final screen = File('lib/professional/screens/professional_inventory_screen.dart').readAsStringSync();
      expect(screen, contains('AUTHORITY UNAVAILABLE'),
          reason: 'Inventory must display AUTHORITY UNAVAILABLE when tier is null — fail closed');
      expect(screen, contains('safeTier'),
          reason: 'Inventory must use safeTier (returns null for UNQUALIFIED) as fail-closed gate');
    });

    test('C54-3: professional_inventory_screen navigates to trust result, not a shortcut tier display', () {
      final screen = File('lib/professional/screens/professional_inventory_screen.dart').readAsStringSync();
      expect(screen, contains('/verify/'),
          reason: 'Inventory must navigate to /verify/:id for full trust result detail');
      expect(screen, isNot(contains('selectTier')),
          reason: 'Inventory must not allow tier selection');
      expect(screen, isNot(contains('tier_selector')),
          reason: 'Inventory must not have tier selector');
    });

    test('C54-4: professional inventory route registered in router', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      expect(router, contains("'inventory'"),
          reason: '/professional/inventory route must be registered');
      expect(router, contains('ProfessionalInventoryScreen'),
          reason: 'Router must reference ProfessionalInventoryScreen');
      expect(router, contains("professional-inventory"),
          reason: 'named route professional-inventory must be registered');
    });
  });

  group('M2-50-08 Physical-Match Gate — Professional Screens (C55)', () {
    test('C55-1: professional_batch_screen has user-visible physical-match unavailability gate', () {
      final screen = File('lib/professional/screens/professional_batch_screen.dart').readAsStringSync();
      expect(screen, contains('Physical object matching: not available'),
          reason: 'Batch screen must explicitly disclose physical match is unavailable — REQ-027');
      expect(screen, contains('PHYSICAL_MATCH_NOT_SUPPORTED'),
          reason: 'Batch screen must annotate PHYSICAL_MATCH_NOT_SUPPORTED');
    });

    test('C55-2: professional_inventory_screen has user-visible physical-match unavailability gate', () {
      final screen = File('lib/professional/screens/professional_inventory_screen.dart').readAsStringSync();
      expect(screen, contains('Physical object matching: not available'),
          reason: 'Inventory screen must explicitly disclose physical match is unavailable — REQ-027');
      expect(screen, contains('PHYSICAL_MATCH_NOT_SUPPORTED'),
          reason: 'Inventory screen must annotate PHYSICAL_MATCH_NOT_SUPPORTED');
    });
  });

  group('M2-50-09 My PV Freshness — Stale-Retention Boundary (C56 — STATIC_CONTRACT)', () {
    test('C56-1 STATIC_CONTRACT: assetDetailProvider is autoDispose — fresh on same-ID re-entry', () {
      final provider = File('lib/my_pv/providers/my_pv_provider.dart').readAsStringSync();
      expect(provider, contains('FutureProvider.autoDispose.family'),
          reason: 'assetDetailProvider must be autoDispose so re-entering the same asset ID '
              'always fetches fresh server data, not retained in-memory state');
    });

    test('C56-2 STATIC_CONTRACT: main_shell invalidates customerAssetsProvider on My PV tab entry', () {
      final shell = File('lib/core/routing/main_shell.dart').readAsStringSync();
      expect(shell, contains('customerAssetsProvider'),
          reason: 'MainShell must reference customerAssetsProvider for tab-entry invalidation');
      expect(shell, contains('ref.invalidate'),
          reason: 'MainShell must call ref.invalidate to discard retained list state on My PV tab entry');
      expect(shell, contains('_myPvBranchIndex'),
          reason: 'MainShell must name the My PV branch index constant for clarity and auditability');
    });

    test('C56-3 STATIC_CONTRACT: my_pv_screen invalidates list after returning from asset detail', () {
      final screen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      expect(screen, contains('await context.push'),
          reason: 'Asset detail navigation must be awaited so list invalidation fires on return');
      expect(screen, contains('ref.invalidate(customerAssetsProvider)'),
          reason: 'customerAssetsProvider must be invalidated after returning from asset detail '
              'so the list fetches fresh server state on reveal');
    });
  });
}
