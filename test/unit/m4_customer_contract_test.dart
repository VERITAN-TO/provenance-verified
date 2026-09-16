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

    // R17 semantic regression locks — added by PV-M2-LEAD-C-NATIVE-CONTINUE-F628961-R17
    test('determination section surface law: server-determined tier, CUSTOMER_SELECTS_TIER=FALSE, no Gold Seal', () {
      final screen = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // CUSTOMER_SELECTS_TIER=FALSE annotation must be present on the determination section
      expect(screen, contains('CUSTOMER_SELECTS_TIER = FALSE'));
      // Section must display DETERMINATION RESULT header, not a Gold Seal assertion
      expect(screen, contains('DETERMINATION RESULT'));
      // Tier must be server-authored dynamic value (det.tier), not a hardcoded Gold Seal string
      expect(screen, contains('det.tier'));
      expect(screen, isNot(contains("'T4 — PV GOLD SEAL'")));
      expect(screen, isNot(contains("'T4 GOLD SEAL'")));
      // Determination explanations must be present (server-authored, not client-selected)
      expect(screen, contains('WHY THIS TIER'));
      expect(screen, contains('WHY NOT HIGHER'));
      expect(screen, contains('LIMITATIONS'));
    });

    test('activity list projects server determination only, BILLING_FOLLOWS_DETERMINATION surface', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // determinedTier display must be bounded to server-authored result
      expect(activity, contains('Server-authored determination result'));
      expect(activity, contains("'Determined: \${item.determinedTier}'"));
      // Must not project determinedTier as Gold Seal or payment-purchased product
      expect(activity, isNot(contains("'Determined: T4 GOLD'")));
      expect(activity, isNot(contains("'T4 GOLD SEAL'")));
    });

    // R19 semantic regression locks — added by PV-M2-LEAD-C-PEACP-R19
    test('no funded/payment-grants-tier language in native activity — BILLING_FOLLOWS_DETERMINATION', () {
      // B a5eee55a fixed web portal legacy-order label "Your verification is funded"
      // (BILLING_FOLLOWS_DETERMINATION=TRUE violation). Native has no equivalent
      // legacy-order state display (PARITY_NO_NATIVE_MUTATION). Lock permanence.
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      expect(activity, isNot(contains('verification is funded')));
      expect(activity, isNot(contains('Your verification is')));
      expect(activity, isNot(contains('payment grants')));
      expect(activity, isNot(contains('PAYMENT_GRANTS')));
      // Submission detail must not say payment grants tier
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      expect(detail, isNot(contains('verification is funded')));
      expect(detail, isNot(contains('payment grants')));
    });

    test('no native pricing page or PricingTierCTA — CUSTOMER_SELECTS_TIER=FALSE on pricing surface', () {
      // A af7d4aa8 added CUSTOMER_SELECTS_TIER=FALSE enforcement to web pricing page
      // and ported analytics event rename (pricing_tier_selected → pricing_tier_cta_clicked).
      // Native has no pricing page or PricingTierCTA component (PARITY_NO_NATIVE_MUTATION).
      // Lock that no customer-selects-tier pricing surface is ever introduced.
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      expect(submit, isNot(contains('pricing_tier_selected')));
      expect(submit, isNot(contains('PricingTierCTA')));
      expect(submit, isNot(contains('/checkout?service=')));
      // Educational trust ladder must not present tiers as purchasable products
      expect(submit, isNot(contains('Get T2')));
      expect(submit, isNot(contains('Get T3')));
      expect(submit, isNot(contains('Get T4')));
    });

    test('ServiceTierCard has no selection params — CUSTOMER_SELECTS_TIER=FALSE on tier display widget', () {
      // R19 cleanup: removed vestigial isSelected/onSelect from ServiceTierCard
      // that were "kept for source compatibility while selection authority is being removed."
      // The card is an educational display only; selection authority fully removed.
      final card = File('lib/submit/widgets/service_tier_card.dart').readAsStringSync();
      expect(card, isNot(contains('isSelected')));
      expect(card, isNot(contains('onSelect')));
      expect(card, isNot(contains('VoidCallback')));
      expect(card, contains('Your evidence determines whether this state is earned.'));
    });

    test('SubmissionDraft has no selectedTier field — CUSTOMER_SELECTS_TIER=FALSE in submit model', () {
      // R19 cleanup: removed SubmissionDraft.selectedTier dead field and
      // SubmitNotifier.selectTier() dead method. Neither was ever sent to the server.
      final models = File('lib/submit/models/submit_models.dart').readAsStringSync();
      expect(models, isNot(contains('selectedTier')));
      expect(models, isNot(contains('Deprecated compatibility field')));
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      expect(provider, isNot(contains('selectTier')));
      expect(provider, isNot(contains('@Deprecated')));
    });

    // R18 semantic regression locks — added by PV-M2-LEAD-C-PEACP-R18
    test('no customer-selectable checkout path — CUSTOMER_SELECTS_TIER=FALSE on settlement surface', () {
      // B 3aba088c removed the web /checkout?service= customer-tier-select route
      // (CUSTOMER_SELECTS_TIER=FALSE violation). Native never had this route
      // (PARITY_NATIVE_AHEAD). This lock confirms the invariant is permanent.
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Native must not have a customer-tier-select checkout route
      expect(submit, isNot(contains('/checkout?service=')));
      // Native must not send customer-chosen serviceCode as Stripe payment authority
      expect(submit, isNot(contains("serviceCode: draft.selectedTier")));
      expect(submit, isNot(contains("'checkout?service='")));
      // Settlement surface must be determination-anchored, not tier-selection-anchored
      expect(submit, contains('DETERMINATION'));
    });

    // R20 resilience regression locks — added by PV-M2-LEAD-C-PEACP-R20
    test('C20-1: router errorBuilder has bounded not-found recovery — no raw URI dump', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      // Router must not dump raw URI as the only content (was: 'Page not found: ${state.uri}')
      expect(router, isNot(contains("'Page not found: \${state.uri}'")));
      // Must have a recovery action to Verify tab
      expect(router, contains("context.go('/verify')"));
      // Must have Semantics label for screen readers
      expect(router, contains('Semantics'));
      // Must import PvColors and PvTypography for design-system consistency
      expect(router, contains("import '../../design/pv_colors.dart'"));
    });

    test('C20-2: TrustResultScreen._ErrorView distinguishes not-found from generic errors', () {
      final trust = File('lib/trust/screens/trust_result_screen.dart').readAsStringSync();
      // Must have not-found detection beyond generic error
      expect(trust, contains('isNotFound'));
      // Must have Semantics on error view
      expect(trust, contains('Semantics'));
      // Must have a "Go Back" recovery for not-found (not just Retry which is wrong for 404)
      expect(trust, contains("'Go Back'"));
      // Retry remains for network/generic errors
      expect(trust, contains("'Retry'"));
    });

    test('C20-3: ReceiptDetailScreen has bounded error and not-found states — no naked Text(e.toString())', () {
      final receipt = File('lib/reliance/screens/receipt_detail_screen.dart').readAsStringSync();
      // Must not have naked error text (was: Center(child: Text(e.toString())))
      expect(receipt, isNot(contains('Center(child: Text(e.toString()))')));
      // Must not have unstyled not-found (was: Center(child: Text(\'Receipt not found\')))
      expect(receipt, isNot(contains("const Center(child: Text('Receipt not found'))")));
      // Must have Semantics on error states
      expect(receipt, contains('Semantics'));
      // Must have recovery actions (back or retry buttons)
      expect(receipt, contains("'Go Back'"));
    });

    test('C20-4: RelianceScreen blocks reliance for REVOKED/SUSPENDED lifecycle states', () {
      final reliance = File('lib/reliance/screens/reliance_screen.dart').readAsStringSync();
      // Must check lifecycle status before allowing reliance
      expect(reliance, contains('lifecycleBlocked'));
      // Must have the blocked lifecycle set
      expect(reliance, contains('REVOKED'));
      expect(reliance, contains('SUSPENDED'));
      // Save button must be disabled when lifecycle is blocked
      expect(reliance, contains('lifecycleBlocked'));
      // Must include "LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY" law comment
      expect(reliance, contains('LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY'));
    });

    test('C20-5: submit wizard has auth recovery redirect on 401 — terminal auth failure sends to sign-in', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Must detect terminal 401 (refresh path exhausted in API client) and redirect
      expect(submit, contains('e.statusCode == 401'));
      // Must redirect to sign-in, not just show a generic error banner
      expect(submit, contains("'/sign-in"));
      // 401 handler must include a redirect (context.push), not just _setError
      expect(submit, contains('context.push'));
    });

    test('C20-6: submit wizard re-fetches quote on re-entry at step 4+ — interruption recovery', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Must detect re-entry at step 4+ with null quote and refetch
      expect(submit, contains('draft.step >= 4'));
      expect(submit, contains('_refetchQuote'));
      // Refetch method must exist
      expect(submit, contains('Future<void> _refetchQuote()'));
    });

    test('C20-7: Android manifest has pv:// deep-link intent-filter — iOS/Android parity', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      // Android must declare the pv:// scheme to match iOS CFBundleURLSchemes
      expect(manifest, contains('android:scheme="pv"'));
      // Must have VIEW action (not just MAIN)
      expect(manifest, contains('android.intent.action.VIEW'));
      // Must have BROWSABLE category for external link handling
      expect(manifest, contains('android.intent.category.BROWSABLE'));
    });

    test('C20-8: AssetDetailScreen._ErrorView has distinct not-found recovery — no misleading Pull down to retry for 404', () {
      final asset = File('lib/my_pv/screens/asset_detail_screen.dart').readAsStringSync();
      // Must have distinct not-found detection beyond just not_found string
      expect(asset, contains('isNotFound'));
      // Must NOT show "Pull down to retry" for not-found (misleading action for 404)
      // The not-found branch must lead to a back navigation, not pull-down
      expect(asset, contains("'Return to My PV'"));
      // Must have Semantics label for accessibility
      expect(asset, contains('Semantics'));
    });
  });
}
