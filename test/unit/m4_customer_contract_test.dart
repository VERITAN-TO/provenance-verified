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

    test('C20-9: SubmissionDetail.requestedServiceTier has decode-only annotation in activity_models — not rendered as trust authority', () {
      final activity = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // Decode-only comment must appear — present in SubmissionStatusItem AND SubmissionDetail
      expect(activity, contains('Decode-only: retained for backward-compat JSON parsing only'));
      // Must NOT be projected as current trust state: comment must appear twice (once per class)
      final first = activity.indexOf('Decode-only: retained for backward-compat JSON parsing only');
      final last = activity.lastIndexOf('Decode-only: retained for backward-compat JSON parsing only');
      expect(first, isNot(equals(last)), reason: 'decode-only annotation must appear in both SubmissionStatusItem and SubmissionDetail');
    });

    test('C20-10: ServiceTier.serviceCode annotated as not-for-client-submission — GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY law present', () {
      final models = File('lib/submit/models/submit_models.dart').readAsStringSync();
      // Annotation must state this string is NEVER sent to the server
      expect(models, contains('NEVER sent to the server'));
      // Gold Seal authority law must be explicitly stated
      expect(models, contains('GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE'));
    });

    test('C20-11: MyPvScreen._ErrorView has Semantics + Retry button + 401 auth detection + spinner semanticsLabel', () {
      final myPv = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      // Semantics wrapper must be present on error view
      expect(myPv, contains('Semantics'));
      // 401 detection must be present alongside not_authenticated string check
      expect(myPv, contains("'401'"));
      // Retry button must exist for non-auth errors so users can recover without pull-to-refresh
      expect(myPv, contains("'Retry'"));
      // Retry button must invalidate the provider (not a no-op)
      expect(myPv, contains('customerAssetsProvider'));
      // Loading spinner must have a semanticsLabel for screen reader users
      expect(myPv, contains("semanticsLabel: 'Loading your assets'"));
    });

    test('C20-12: WhyThisTierScreen — T4 description must not say "Gold Standard"; must reference governed authority and separate issuance', () {
      final why = File('lib/trust/screens/why_this_tier_screen.dart').readAsStringSync();
      // Must not use "Gold Standard" — that is a product law violation
      expect(why, isNot(contains('Gold Standard')));
      // Must use T4 governed authority framing
      expect(why, contains('Governed Provenance Authority'));
      // Must state T4 determination alone does not issue a Gold Seal
      expect(why, contains('Gold Seal'));
    });

    test('C20-13: WhyNotHigherScreen — T4 banner must not say "Gold Standard"; must reference governed authority', () {
      final why = File('lib/trust/screens/why_not_higher_screen.dart').readAsStringSync();
      // Must not use "Gold Standard"
      expect(why, isNot(contains('Gold Standard')));
      // Must use T4 governed authority framing
      expect(why, contains('Governed Provenance Authority'));
      // Must state T4 determination is separate from Gold Seal issuance
      expect(why, contains('Gold Seal'));
    });

    test('C20-14: ReceiptListScreen has styled error view with Semantics + Retry + spinner semanticsLabel', () {
      final receipts = File('lib/reliance/screens/receipt_list_screen.dart').readAsStringSync();
      // Loading spinner must have semanticsLabel
      expect(receipts, contains("semanticsLabel: 'Loading reliance receipts'"));
      // Error view must have Semantics (no raw Text(e.toString()))
      expect(receipts, contains('Semantics'));
      // Must have Retry button (not just a naked error text)
      expect(receipts, contains("'Retry'"));
      // Must invalidate provider for the retry to work
      expect(receipts, contains('receiptListProvider'));
      // Must NOT have raw unstyled error: Center(child: Text(e.toString()))
      expect(receipts, isNot(contains('Center(child: Text(e.toString()))')));
    });

    test('C20-15: Trust detail sub-screens (WhyThis, WhyNotHigher, Authority) have styled error + spinner semanticsLabel', () {
      for (final path in [
        'lib/trust/screens/why_this_tier_screen.dart',
        'lib/trust/screens/why_not_higher_screen.dart',
        'lib/trust/screens/authority_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        // Must not have raw unstyled error
        expect(src, isNot(contains('Center(child: Text(e.toString()))')), reason: '$path must not have raw error display');
        // Must have Semantics on error
        expect(src, contains('Semantics'), reason: '$path must have Semantics on error state');
        // Must have Retry
        expect(src, contains("'Retry'"), reason: '$path must have Retry button');
        // Must have spinner semanticsLabel
        expect(src, contains('semanticsLabel:'), reason: '$path must have spinner semanticsLabel');
      }
    });

    // ── R11 REGRESSION LOCKS ───────────────────────────────────────────────────────────────────────────
    // These tests lock out semantic/authority leaks identified in R11 cleanup.
    // CUSTOMER_SELECTS_TIER=FALSE  REVIEWER_SELECTS_TIER=FALSE
    // T4_DETERMINATION_IS_OFFICIAL_T4=FALSE  GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE

    test('C21-1: SubmitScreen — no "review team" as tier selector; canonical T1-T4 names present', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // No "review team" as tier authority (REVIEWER_SELECTS_TIER=FALSE)
      expect(submit, isNot(contains('review team')));
      // Canonical T1 name must be present
      expect(submit, contains('T1 — Accountable Existence'));
      // Canonical T2 name must be present
      expect(submit, contains('T2 — Accountable Declaration'));
      // Canonical T3 name must be present
      expect(submit, contains('T3 — Evidence-Established Trust'));
      // Canonical T4 name must be present
      expect(submit, contains('T4 — Highest Governed Provenance Authority'));
    });

    test('C21-2: SubmitScreen — no T4 Gold Seal label; Gold Seal requires separate authority', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Must not display "PV GOLD SEAL" as a tier name or product label in the UI
      expect(submit, isNot(contains('PV GOLD SEAL')));
      // T4 description must reference separate authority chain
      expect(submit, contains('Gold Seal'));
      // Must carry T4_DETERMINATION_IS_OFFICIAL_T4=FALSE signal in source
      expect(submit, contains('T4_DETERMINATION_IS_OFFICIAL_T4=FALSE'));
    });

    test('C21-3: SubmitScreen — no provenance fingerprint language; no SELF-REPORTED label', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // No "provenance fingerprint" — that is not an official tier concept
      expect(submit, isNot(contains('provenance fingerprint')));
      // No SELF-REPORTED label — customer input is not a trust authority
      expect(submit, isNot(contains('SELF-REPORTED')));
    });

    test('C21-4: SubmitScreen — determination-first control flow; evaluation precedes payment', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // saveDeclarations must appear before submitForEvaluation
      final saveIdx = submit.indexOf('saveDeclarations');
      final evalIdx = submit.indexOf('submitForEvaluation');
      final quoteIdx = submit.indexOf('fetchQuote');
      expect(saveIdx, isNot(-1), reason: 'saveDeclarations must be present');
      expect(evalIdx, isNot(-1), reason: 'submitForEvaluation must be present');
      expect(quoteIdx, isNot(-1), reason: 'fetchQuote must be present');
      // Control flow: save → eval → quote (never quote then eval)
      expect(saveIdx, lessThan(evalIdx), reason: 'saveDeclarations must precede submitForEvaluation');
      expect(evalIdx, lessThan(quoteIdx), reason: 'submitForEvaluation must precede fetchQuote');
    });

    test('C21-5: ActivityScreen — no "certification" language for empty-state CTA; must use evaluation framing', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // Empty-state CTA must not say "certification" — implies pre-authority-chain issuance
      // GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE; evaluation is the right framing
      expect(activity, isNot(contains('Submit a gemstone for certification')));
      // Must use PROVENANCE VERIFIED evaluation framing instead
      expect(activity, contains('PROVENANCE VERIFIED'));
    });

    test('C21-6: ActivityScreen — no customer-facing "Requested:" tier fallback', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // Must not display customer-selected tier as a trust authority fallback
      // CUSTOMER_SELECTS_TIER=FALSE — the displayed tier comes from server determination only
      expect(activity, isNot(contains("'Requested: \${item.requestedServiceTier}'")));
      expect(activity, isNot(contains('"Requested: ')));
    });

    test('C21-7: SubmissionDetailScreen — no "Requested Service" tier displayed as trust authority', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // Must not render customer-submitted tier as a trust-authority field
      expect(detail, isNot(contains("'Requested Service'")));
      expect(detail, isNot(contains('"Requested Service"')));
      // Must not display requestedServiceTier as current trust state
      expect(detail, isNot(contains('requestedServiceTier')));
    });

    test('C21-8: No selectTier / selectedTier in submit or activity screens — CUSTOMER_SELECTS_TIER=FALSE', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // Customer tier selection must be entirely absent from these surfaces
      expect(submit, isNot(contains('selectTier')));
      expect(submit, isNot(contains('selectedTier')));
      expect(activity, isNot(contains('selectTier')));
      expect(activity, isNot(contains('selectedTier')));
    });

    // ── R21 PARITY LOCKS ───────────────────────────────────────────────────────────────────────────
    // Locks for A/B deltas consumed in R21: be5b164 (upload trust-law) and
    // e8cca3f (public_id / determined_at in submission detail).
    // CUSTOMER_UPLOAD_AUTO_INDEPENDENT=FALSE  CUSTOMER_UPLOAD_AUTO_QUALIFIED=FALSE

    test('C22-1: Evidence upload multipart carries explicit trust-law classification — not inferred from missing fields', () {
      final provider = File('lib/submit/providers/submit_provider.dart').readAsStringSync();
      // Explicit independent=false must be sent — server must not infer from absence
      expect(provider, contains("'independent'"));
      expect(provider, contains("'false'"));
      // Explicit related_party=true
      expect(provider, contains("'related_party'"));
      expect(provider, contains("'true'"));
      // Explicit qualified_review_eligible=false
      expect(provider, contains("'qualified_review_eligible'"));
      // Trust-law annotation must be present in source
      expect(provider, contains('CUSTOMER_UPLOAD_AUTO_INDEPENDENT=FALSE'));
      expect(provider, contains('CUSTOMER_UPLOAD_AUTO_QUALIFIED=FALSE'));
    });

    test('C22-2: SubmissionDetail decodes public_id → publicId and determinedAt; R32: payment-gated Public Verify removed', () {
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // publicId field must be decoded from server response
      expect(models, contains("json['public_id']"));
      expect(models, contains('publicId'));
      // determinedAt must be decoded
      expect(models, contains("json['determined_at']"));
      expect(models, contains('determinedAt'));
      // MTA-1 law comment must be present — server determines, native displays
      expect(models, contains('MTA-1: SERVER DETERMINES TRUST'));
      // R29: hasSettlementSeam and settlementData decoded from data.settlement
      expect(models, contains('hasSettlementSeam'));
      expect(models, contains('settlementData'));
      expect(models, contains("json.containsKey('settlement')"));
      // Settlement authority seam wired in detail screen
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // publicId reference must exist in model decode (retained)
      expect(models, contains('publicId'));
      // R32: _ProvenanceRecordAction removed — payment-gated Public Verify is dead code
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      expect(detail, contains('_ProvenanceRecordAction removed in R32'));
      // publicId-alone gate must be absent (never a registry authority)
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      // R32: isSettled is NOT used as a Verify gate — MONEY_CONTROLS_TRUST = FALSE
      expect(detail, isNot(contains('settlementData!.isSettled')));
      // R32: CROSS_LANE_HANDOFF_REQUIRED annotation present
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
      // hasSettlementSeam still present (for settlement CTA gate)
      expect(detail, contains('hasSettlementSeam'));
      // Must have Semantics for screen reader (custody timeline)
      expect(detail, contains('Semantics'));
    });

    test('C23-1: auth screens use go_router context.go — no Navigator.pushReplacementNamed', () {
      final signIn = File('lib/auth/screens/sign_in_screen.dart').readAsStringSync();
      final signUp = File('lib/auth/screens/sign_up_screen.dart').readAsStringSync();
      // go_router must be imported
      expect(signIn, contains("import 'package:go_router/go_router.dart'"));
      expect(signUp, contains("import 'package:go_router/go_router.dart'"));
      // Navigator 1.0 named routes must not be used (breaks deep-link recovery)
      expect(signIn, isNot(contains('pushReplacementNamed')));
      expect(signUp, isNot(contains('pushReplacementNamed')));
      // go_router navigation must be present
      expect(signIn, contains('context.go('));
      expect(signUp, contains('context.go('));
    });

    test('C23-2: reliance provider fails closed on server error — SocketException/TimeoutException only for offline fallback', () {
      final provider = File('lib/reliance/providers/reliance_provider.dart').readAsStringSync();
      // Must import dart:io and dart:async for offline-only exception types
      expect(provider, contains("import 'dart:io'"));
      expect(provider, contains("import 'dart:async'"));
      // Must catch SocketException for offline fallback
      expect(provider, contains('SocketException'));
      // Must catch TimeoutException for offline fallback
      expect(provider, contains('TimeoutException'));
      // B delta annotation must be present: server fails closed
      expect(provider, contains('B delta'));
      // Must NOT have a bare catch (_) that silently swallows ApiException
      // (a catch-all swallow would allow fabricated receipts on server 5xx)
      expect(provider, isNot(contains('} catch (_) {\n        // Fallback to local receipt on server failure')));
    });

    // ── R23 VISUAL/INTERACTION FINISH LOCKS ────────────────────────────────────────────
    // B delta: SHA-256 identity binding (4e676e1, 88d8c19) + auto-claim-credit
    // law (1df35fa) require native Step 2 to surface evidence credit policy.
    // CUSTOMER_UPLOAD_AUTO_CLAIM_CREDIT=FALSE  CUSTOMER_UPLOAD_AUTO_INDEPENDENT=FALSE

    test('C24-1: Step 2 evidence upload surfaces SHA-256 binding and auto-claim-credit prohibition', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // SHA-256 binding notice must be present (B delta 4e676e1)
      expect(submit, contains('SHA-256'));
      // Auto-claim-credit prohibition must be visible to users (1df35fa)
      // "governs evidence credit independently" covers CUSTOMER_UPLOAD_AUTO_CLAIM_CREDIT=FALSE
      expect(submit, contains('governs evidence credit independently'));
    });

    test('C24-2: Step 6 confirmation back button routes to /my-pv not /home', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // /home is not a registered route — must use /my-pv
      expect(submit, isNot(contains("context.go('/home')")));
      // Correct route: /my-pv
      expect(submit, contains("context.go('/my-pv')"));
    });

    test('C24-3: Step 4 determination result has retry path when quote is unavailable', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // Retry callback parameter must be present on Step 4 widget
      expect(submit, contains('onRetry'));
      // Retry must be passed from parent state (_refetchQuote)
      expect(submit, contains('_refetchQuote'));
    });

    test('C24-4: Step 4 surfaces T4 Gold Seal separation notice for T4 tier', () {
      final submit = File('lib/submit/screens/submit_screen.dart').readAsStringSync();
      // T4 case in Step 4 must reference Gold Seal separation
      // GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE; GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY_CHAIN=TRUE
      expect(submit, contains("q.tier == 'T4'"));
      // Must say "separate authority chain" for T4 case
      expect(submit, contains('separate authority chain'));
    });

    // ── R24 NAVIGATOR 1.0 ERADICATION LOCKS ──────────────────────────────────────────
    // Two Navigator 1.0 usages were found and eradicated in R24:
    //   1. submission_detail_screen.dart AppBar back button
    //   2. activity_screen.dart row tap → SubmissionDetailScreen
    // go_router (context.pop / context.push) must be used exclusively.

    test('C25-1: SubmissionDetailScreen AppBar back uses go_router — no Navigator.of(context).pop()', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // go_router import must be present
      expect(detail, contains("import 'package:go_router/go_router.dart'"));
      // Navigator 1.0 pop must be absent from back button
      expect(detail, isNot(contains('Navigator.of(context).pop()')));
      // go_router pop must be used instead
      expect(detail, contains('context.pop()'));
    });

    test('C25-2: ActivityScreen row tap uses go_router — no MaterialPageRoute or Navigator.push', () {
      final activity = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // go_router import must be present
      expect(activity, contains("import 'package:go_router/go_router.dart'"));
      // Navigator 1.0 imperative push must be absent
      expect(activity, isNot(contains('Navigator.of(context).push(')));
      expect(activity, isNot(contains('MaterialPageRoute(')));
      // go_router context.push must navigate to the /activity/:id route
      expect(activity, contains("context.push("));
      expect(activity, contains("'/activity/\${items[i].submissionId}'"));
    });

    test('C25-3: App router registers /activity/:submissionId route — SubmissionDetailScreen reachable via URL', () {
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      // SubmissionDetailScreen import must be present in router
      expect(router, contains("import '../../activity/screens/submission_detail_screen.dart'"));
      // Named route submission-detail must be present
      expect(router, contains("name: 'submission-detail'"));
      // pathParameters['submissionId'] must be used for the ID
      expect(router, contains("pathParameters['submissionId']"));
    });

    // ── R28 PUBLIC RELIANCE FAILSAFE LOCKS ───────────────────────────────────────────────
    // CTO_WORK_ORDER_ID: PV-M2-LEAD-C-R28-PUBLIC-RELIANCE-FAILSAFE-32B3
    // publicId alone (or any combination of determination/payment state) is NOT
    // a canonical registry/lifecycle-active authority signal. Settlement null is
    // ambiguous. Both actions suppressed until explicit server seam is added.
    // CUSTOMER_SELECTS_TIER=FALSE  MONEY_CONTROLS_TRUST=FALSE

    test('C28-1: publicId alone must not unlock a public-reliance Verify action — R32: payment gate removed, CROSS_LANE_HANDOFF_REQUIRED', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // publicId-alone gate must be absent (not a registry authority by itself)
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      // R32: _ProvenanceRecordAction removed — payment-gated Verify widget is gone
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      // R32: isSettled is NOT used as a Verify gate — MONEY_CONTROLS_TRUST = FALSE
      expect(detail, isNot(contains('settlementData!.isSettled')));
      // R32: CROSS_LANE_HANDOFF_REQUIRED annotation must be present
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
      // MONEY_CONTROLS_TRUST annotation must remain
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
    });

    test('C28-2: payment state alone does not unlock public-reliance Verify — R32: gate removed entirely, CROSS_LANE_HANDOFF_REQUIRED', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // Settlement status display (informational badge) must still be present
      expect(detail, contains('_SettlementStatusSection'));
      // My-PV navigation for FREE/PAID settlement must still be present
      expect(detail, contains('_MyPvNavigationSection'));
      // R32: payment-gated isSettled Verify gate removed — MONEY_CONTROLS_TRUST = FALSE strengthened
      expect(detail, isNot(contains('settlementData!.isSettled')));
      // MONEY_CONTROLS_TRUST=FALSE annotation must be present
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
      // R32: CROSS_LANE_HANDOFF_REQUIRED annotation must be present
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    test('C28-3: settlement CTA wired in R29 — hasSettlementSeam gate replaces null-ambiguous suppression', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // Null-only gate must be absent (null alone was ambiguous — requires key-presence seam)
      expect(detail, isNot(contains('detail.settlementPaymentStatus == null')));
      // R29: CTA gated on hasSettlementSeam (server sent settlement key)
      expect(detail, contains('detail.hasSettlementSeam'));
      // _SettlementCtaSection class must exist and be callable
      expect(detail, contains('class _SettlementCtaSection'));
      // MONEY_CONTROLS_TRUST annotation must be present
      expect(detail, contains('MONEY_CONTROLS_TRUST'));
    });

    test('C28-4: unknown/error settlement state must not enable settlement CTA — R29 gate requires hasSettlementSeam+null data', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // unknown gates out the settlement status section — guard must be present
      expect(detail, contains('SettlementPaymentStatus.unknown'));
      // _SettlementCtaSection class must exist (wired in R29)
      expect(detail, contains('class _SettlementCtaSection'));
      // CTA gate must require hasSettlementSeam (key-presence guard, not null guard alone)
      expect(detail, contains('detail.hasSettlementSeam'));
      // CTA gate must require settlementData == null (order not yet linked)
      expect(detail, contains('detail.settlementData == null'));
    });

    test('C28-5: public record authority must not use isSettled — R32: gate removed, CROSS_LANE_HANDOFF_REQUIRED', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // Model must not introduce a registry_active field
      expect(model, isNot(contains("'registry_active'")));
      expect(model, isNot(contains('registryActive')));
      // Detail screen must not gate any action on an invented authority field
      expect(detail, isNot(contains("'registry_active'")));
      expect(detail, isNot(contains('registryActive')));
      // R32: isSettled is NOT the authority gate — payment cannot unlock Public Verify
      expect(detail, isNot(contains('settlementData!.isSettled')));
      // R32: CROSS_LANE_HANDOFF_REQUIRED — no explicit public-record authority in current server contract
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    // ── R29 SETTLEMENT AUTHORITY SEAM LOCKS ──────────────────────────────────────────────────
    // CTO_WORK_ORDER_ID: PV-M2-LEAD-C-R29-NATIVE-CAPABILITY-CLOSURE
    // PR #47 data.settlement is the explicit server seam for both the settlement
    // CTA and the public provenance record link. Key-presence gate (hasSettlementSeam)
    // is fail-closed against old API responses with no settlement key.
    // MONEY_CONTROLS_TRUST = FALSE  MTA-1: SERVER DETERMINES TRUST

    test('C29-1: Settlement model: isSettled = FREE or PAID; class decoded from data.settlement', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // Settlement class must exist
      expect(model, contains('class Settlement'));
      // isSettled must gate on FREE and PAID
      expect(model, contains("'FREE'"));
      expect(model, contains("'PAID'"));
      expect(model, contains('isSettled'));
      // paymentStatus and orderId fields must be present
      expect(model, contains('paymentStatus'));
      expect(model, contains('orderId'));
      // MONEY_CONTROLS_TRUST = FALSE annotation must be present
      expect(model, contains('MONEY_CONTROLS_TRUST = FALSE'));
    });

    test('C29-2: hasSettlementSeam uses json.containsKey — key-absent old API is fail-closed', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // Key-presence gate is the correct distinguisher: absent key ≠ null settlement
      expect(model, contains("json.containsKey('settlement')"));
      // hasSettlementSeam field must be present on SubmissionDetail
      expect(model, contains('hasSettlementSeam'));
    });

    test('C29-3: _ProvenanceRecordAction removed in R32 — isSettled gate gone, CROSS_LANE_HANDOFF_REQUIRED active', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // R32: _ProvenanceRecordAction widget class removed — payment-gated Public Verify is dead code
      expect(detail, isNot(contains('class _ProvenanceRecordAction')));
      expect(detail, contains('_ProvenanceRecordAction removed in R32'));
      // publicId-alone gate must be absent
      expect(detail, isNot(contains('if (detail.publicId != null)')));
      // R32: isSettled Verify gate removed — MONEY_CONTROLS_TRUST = FALSE
      expect(detail, isNot(contains('settlementData!.isSettled')));
      // R32: CROSS_LANE_HANDOFF_REQUIRED annotation must be present
      expect(detail, contains('CROSS_LANE_HANDOFF_REQUIRED'));
    });

    test('C29-4: Settlement CTA shown when hasSettlementSeam + no order linked + determination present', () {
      final detail = File('lib/activity/screens/submission_detail_screen.dart').readAsStringSync();
      // All three R29 gate components must be present
      expect(detail, contains('detail.hasSettlementSeam'));
      expect(detail, contains('detail.settlementData == null'));
      expect(detail, contains('detail.determination != null'));
      // The CTA call site must now be active
      expect(detail, contains('_SettlementCtaSection(submissionId: detail.submissionId)'));
    });

    test('C29-5: SubmissionDetail.fromJson reads settlement key safely — key-absent and key-present-null both handled', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // fromJson must check key presence before parsing
      expect(model, contains("json.containsKey('settlement')"));
      // settlementData must only be non-null when key is present AND value is a map
      expect(model, contains("json['settlement'] is Map<String, dynamic>"));
      // Both fields must appear in the constructor call
      expect(model, contains('hasSettlementSeam:'));
      expect(model, contains('settlementData:'));
    });

    // ───────────────────────────────────────────────────────────────────────────
    // C30 — R30: credential lifecycle rebind
    // data.credential_lifecycle from PR #48 / pv_credentials via review-case linkage (R34).
    // REGISTRY_STATE_ONLY = TRUE: lifecycle is a separate authority plane.
    // NOT_ISSUED ≠ trust failure.  MTA-1: SERVER DETERMINES TRUST.
    // ───────────────────────────────────────────────────────────────────────────

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
      // Null input returns null (determination not yet available)
      expect(model, contains('if (raw == null) return null'));
      // NOT_ISSUED mapping must be present as an explicit named case
      expect(model, contains("case 'NOT_ISSUED'"));
      // NOT_ISSUED explicit arm maps to notIssued (known neutral state)
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
      // Guard: only rendered when credentialLifecycle is non-null
      expect(detail, contains('detail.credentialLifecycle != null'));
      // Widget receives status from the field (not inlined trust claim)
      expect(detail, contains('status: detail.credentialLifecycle!'));
    });

    // ── R31: Trust currentness — lifecycle-aware UI + approachingStale ──────

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

    // ── R32: fail-closed currentness and settlement authority ─────────────────

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

    // ── R33: list-endpoint determination_state binding + credential authority ruling ──

    test('C33-1: list credential_state placeholder NOT displayed as badge — Core PR48 authority ruling', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // PR47 credential_state on list is a placeholder (currently always NOT_ISSUED).
      // Core PR48: lifecycle_sourced_from_pv_credentials_only=TRUE.
      // List card must NOT display it as a credential badge.
      expect(screen, isNot(contains("item.credentialState!.toUpperCase()")));
      expect(screen, isNot(contains("item.credentialState!.isNotEmpty")));
      // PR47 contract-ready field still parsed in model (data contract preserved) but not displayed.
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('credentialState'));
      expect(models, contains('credential_state'));
    });

    test('C33-2: AUTHORITY_UNAVAILABLE list card — error border + badge; tier suppressed', () {
      final screen = File('lib/activity/screens/activity_screen.dart').readAsStringSync();
      // determination_state == AUTHORITY_UNAVAILABLE must trigger fail-closed display.
      expect(screen, contains("determinationState == 'AUTHORITY_UNAVAILABLE'"));
      expect(screen, contains('PvColors.error'));
      expect(screen, contains('AUTHORITY UNAVAILABLE'));
      // AUTHORITY_UNAVAILABLE must be checked BEFORE determinedTier display.
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
      // List card must not use settlementPaymentStatus to infer or display credential state.
      expect(screen, isNot(contains('settlementPaymentStatus')));
      // List model must carry MTA-1 and MONEY_CONTROLS_TRUST annotations.
      final models = File('lib/activity/models/activity_models.dart').readAsStringSync();
      expect(models, contains('MTA-1: SERVER DETERMINES TRUST'));
      expect(models, contains('MONEY_CONTROLS_TRUST = FALSE'));
    });

    // ── R34: canonical lifecycle source and fail-closed default ───────────────

    test('C34-1: fromApiString default fails closed to authorityUnavailable — not notIssued', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // R34: unrecognized API strings must NOT silently downgrade to notIssued.
      // notIssued is a known neutral state; authorityUnavailable is the correct
      // fail-closed for unrecognized/unknown server strings.
      expect(model, contains('return CredentialLifecycleStatus.authorityUnavailable'));
      // The default arm must return authorityUnavailable, not notIssued.
      // Confirm the default arm is the authorityUnavailable return (not a named case arm).
      final defaultIdx = model.indexOf('default:');
      expect(defaultIdx, greaterThan(0));
      final defaultArm = model.substring(defaultIdx, defaultIdx + 80);
      expect(defaultArm, contains('authorityUnavailable'));
    });

    test('C34-2: credential lifecycle source annotation references pv_credentials — not pv_review_cases', () {
      final model = File('lib/activity/models/activity_models.dart').readAsStringSync();
      // R34: Core PR48 fixed canonical lifecycle source to pv_credentials via review_case_id.
      // Native source-of-authority comments must reflect the corrected path.
      expect(model, contains('pv_credentials'));
      expect(model, isNot(contains('pv_review_cases')));
    });

    // ── R35 ──────────────────────────────────────────────────────────────────
    test('C35-1: my_pv tier labels use canonical Web/Core names — not abbreviated variants', () {
      // R35: my_pv_screen._tierLabel must match CustomerSubmissionDetail.tsx canonical strings.
      final screen = File('lib/my_pv/screens/my_pv_screen.dart').readAsStringSync();
      expect(screen, contains('Accountable Existence'));
      expect(screen, contains('Accountable Declaration'));
      expect(screen, contains('Evidence-Established Trust'));
      expect(screen, contains('Highest Governed Provenance Authority'));
      // Confirm old abbreviated forms are gone.
      expect(screen, isNot(contains("'T1 EXISTENCE'")));
      expect(screen, isNot(contains("'T2 DECLARATION'")));
      expect(screen, isNot(contains("'T3 EVIDENCE-ESTABLISHED'")));
      expect(screen, isNot(contains("'T4 GOVERNED AUTHORITY'")));
    });
  });
}
