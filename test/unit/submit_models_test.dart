// Unit tests for SubmissionQuote.fromJson parsing branches and
// SubmissionDraft invariants not covered by the static-contract suite.

import 'package:test/test.dart';
import 'package:provenance_verified_app/submit/models/submit_models.dart';

void main() {
  // ── SubmissionQuote.fromJson: payment_required inference ──────────────────

  group('SubmissionQuote.fromJson: payment_required inference', () {
    test('payment_required inferred true when base_fee_cents > 0 and key absent', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T3_EVIDENCE_VERIFIED',
        'determined_tier': 'T3',
        'base_fee_cents': 15000,
        'currency': 'USD',
        'price_version': 'v1',
        'csa_version': 'CSA-2026.08',
      });
      expect(quote.paymentRequired, isTrue);
    });

    test('payment_required inferred false when base_fee_cents == 0 and key absent', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T1_FREE_ASSET_FINGERPRINT',
        'determined_tier': 'T1',
        'base_fee_cents': 0,
        'currency': 'USD',
        'price_version': 'v1',
        'csa_version': '',
      });
      expect(quote.paymentRequired, isFalse);
    });
  });

  // ── SubmissionQuote.fromJson: service_description fallback ────────────────

  group('SubmissionQuote.fromJson: service_description fallback to _descriptionFor', () {
    test('T1_FREE_ASSET_FINGERPRINT → Accountable Existence when description absent', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T1_FREE_ASSET_FINGERPRINT',
        'determined_tier': 'T1',
        'base_fee_cents': 0,
        'price_version': 'v1',
        'csa_version': '',
        'payment_required': false,
      });
      expect(quote.serviceDescription, 'Accountable Existence');
    });

    test('unknown service_code falls back to tier label in description', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'UNKNOWN_CODE',
        'determined_tier': 'T3',
        'base_fee_cents': 0,
        'price_version': 'v1',
        'csa_version': '',
        'payment_required': false,
      });
      expect(quote.serviceDescription, contains('T3'));
    });

    test('provided service_description takes precedence over _descriptionFor', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T1_FREE_ASSET_FINGERPRINT',
        'determined_tier': 'T1',
        'base_fee_cents': 0,
        'price_version': 'v1',
        'csa_version': '',
        'payment_required': false,
        'service_description': 'Custom server description',
      });
      expect(quote.serviceDescription, 'Custom server description');
    });
  });

  // ── SubmissionQuote.fromJson: data envelope unwrapping ────────────────────

  group('SubmissionQuote.fromJson: data envelope unwrapping', () {
    test('parses correctly when payload is wrapped under data key', () {
      final quote = SubmissionQuote.fromJson({
        'data': {
          'service_code': 'T2_DECLARED_SOURCE',
          'determined_tier': 'T2',
          'base_fee_cents': 5000,
          'currency': 'USD',
          'price_version': 'v1',
          'csa_version': 'CSA-2026.08',
          'payment_required': true,
        },
      });
      expect(quote.tier, 'T2');
      expect(quote.price, 50.0);
      expect(quote.paymentRequired, isTrue);
    });
  });

  // ── SubmissionQuote.fromJson: determined_tier vs tier key fallback ─────────

  group('SubmissionQuote.fromJson: determined_tier vs tier key fallback', () {
    test('uses tier key when determined_tier is absent', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T3_EVIDENCE_VERIFIED',
        'tier': 'T3',
        'base_fee_cents': 15000,
        'currency': 'USD',
        'price_version': 'v1',
        'csa_version': 'CSA-2026.08',
        'payment_required': true,
      });
      expect(quote.tier, 'T3');
    });
  });

  // ── SubmissionQuote.fromJson: why_not_higher key ──────────────────────────

  group('SubmissionQuote.fromJson: why_not_higher and why_not_next_tier', () {
    test('why_not_higher key populates whyNotNextTier', () {
      final quote = SubmissionQuote.fromJson({
        'service_code': 'T3_EVIDENCE_VERIFIED',
        'determined_tier': 'T3',
        'base_fee_cents': 15000,
        'price_version': 'v1',
        'csa_version': 'CSA-2026.08',
        'payment_required': true,
        'why_not_higher': 'T4 evidence prerequisites not satisfied',
      });
      expect(quote.whyNotNextTier, 'T4 evidence prerequisites not satisfied');
    });
  });

  // ── SubmissionDraft.declarationsComplete ──────────────────────────────────

  group('SubmissionDraft.declarationsComplete', () {
    test('true when both declaredAccurate and declaredTermsAgreed are true', () {
      const draft = SubmissionDraft(
        declaredAccurate: true,
        declaredTermsAgreed: true,
      );
      expect(draft.declarationsComplete, isTrue);
    });

    test('false when only declaredAccurate is true', () {
      const draft = SubmissionDraft(
        declaredAccurate: true,
        declaredTermsAgreed: false,
      );
      expect(draft.declarationsComplete, isFalse);
    });

    test('false when only declaredTermsAgreed is true', () {
      const draft = SubmissionDraft(
        declaredAccurate: false,
        declaredTermsAgreed: true,
      );
      expect(draft.declarationsComplete, isFalse);
    });

    test('false when both declarations are false', () {
      const draft = SubmissionDraft();
      expect(draft.declarationsComplete, isFalse);
    });
  });
}
