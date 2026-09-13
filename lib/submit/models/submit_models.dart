// Submit models — gemstone verification submission workflow.
//
// MONEY_CONTROLS_TRUST = FALSE
// VERIFIED_HUMAN_CLAIMANT_REQUIRED = TRUE
// Customer-selected tier is a REQUESTED SERVICE, not a guaranteed outcome.
// The determined trust state is set exclusively by the governed backend after review.

enum ServiceTier {
  t1Free,
  t2Standard,
  t3Professional,
  t4Certified;

  String get displayName {
    switch (this) {
      case ServiceTier.t1Free:         return 'T1 — Verified Claimant + Asset Fingerprint';
      case ServiceTier.t2Standard:     return 'T2 — Declared Source Record';
      case ServiceTier.t3Professional: return 'T3 — Evidence-Verified Provenance';
      case ServiceTier.t4Certified:    return 'T4 — PROVENANCE VERIFIED™ Gold Seal Review';
    }
  }

  String get apiValue {
    switch (this) {
      case ServiceTier.t1Free:         return 'T1';
      case ServiceTier.t2Standard:     return 'T2';
      case ServiceTier.t3Professional: return 'T3';
      case ServiceTier.t4Certified:    return 'T4';
    }
  }

  String get serviceCode {
    switch (this) {
      case ServiceTier.t1Free:         return 'T1_FREE_ASSET_FINGERPRINT';
      case ServiceTier.t2Standard:     return 'T2_DECLARED_SOURCE';
      case ServiceTier.t3Professional: return 'T3_EVIDENCE_VERIFIED';
      case ServiceTier.t4Certified:    return 'T4_PV_GOLD_SEAL';
    }
  }

  String get priceRange {
    switch (this) {
      case ServiceTier.t1Free:         return 'Free';
      case ServiceTier.t2Standard:     return '\$50';
      case ServiceTier.t3Professional: return '\$150';
      case ServiceTier.t4Certified:    return '\$350';
    }
  }

  String get shortDescription {
    switch (this) {
      case ServiceTier.t1Free:
        return 'A real, verified person takes responsibility for a stable physical-asset record. No provenance claim is verified.';
      case ServiceTier.t2Standard:
        return 'A verified claimant makes an attributable source/origin declaration. PV records who said what; the source is not independently verified.';
      case ServiceTier.t3Professional:
        return 'Claims are mapped to evidence, checked for contradiction, reviewed, and deterministically bounded with reasons and limitations.';
      case ServiceTier.t4Certified:
        return 'Highest PV review path. Gold Seal credential and mark authority exist only if every evidence, approval, signing, and lifecycle gate is earned.';
    }
  }

  String get machineTrustState {
    switch (this) {
      case ServiceTier.t1Free:
        return 'CLAIMANT VERIFIED • ASSET REGISTERED • PROVENANCE UNVERIFIED';
      case ServiceTier.t2Standard:
        return 'CLAIMANT VERIFIED • SOURCE DECLARED • INDEPENDENT VERIFICATION NOT YET EARNED';
      case ServiceTier.t3Professional:
        return 'EVIDENCE VERIFIED • REASON-CODED DETERMINATION • EXPLICIT LIMITATIONS';
      case ServiceTier.t4Certified:
        return 'GOLD SEAL ELIGIBLE ONLY IF DETERMINED • MARK AUTHORITY CONTROLLED';
    }
  }

  List<String> get features {
    switch (this) {
      case ServiceTier.t1Free:
        return [
          'Government-issued photo ID + matching selfie required',
          'Stable asset fingerprint under an accountable claimant',
          'Tamper-evident PV record',
          'Does not prove origin, source, custody history, or provenance',
        ];
      case ServiceTier.t2Standard:
        return [
          'Everything in T1 identity/accountability',
          'Structured source/origin claim attributed to the verified declarant',
          'Signed customer attestation and machine-readable declaration state',
          'Declared does not mean independently verified',
        ];
      case ServiceTier.t3Professional:
        return [
          'Claim-to-evidence mapping and evidence sufficiency review',
          'Contradiction analysis and qualified review',
          'Deterministic determination with why-this-tier / why-not-higher reasons',
          'Explicit evidence scope and limitations',
        ];
      case ServiceTier.t4Certified:
        return [
          'T3 controls plus enhanced evidence and approval requirements',
          'Physical examination / custody controls where protocol requires',
          'Controlled signing and credential lifecycle',
          'PROVENANCE VERIFIED™ mark authority only after independent eligibility gates pass',
        ];
    }
  }
}

class GemstoneAttributes {
  final String species;
  final String variety;
  final String weight;
  final String dimensions;
  final String origin;
  final String treatments;

  const GemstoneAttributes({this.species = '', this.variety = '', this.weight = '', this.dimensions = '', this.origin = '', this.treatments = ''});

  GemstoneAttributes copyWith({String? species, String? variety, String? weight, String? dimensions, String? origin, String? treatments}) => GemstoneAttributes(
    species: species ?? this.species,
    variety: variety ?? this.variety,
    weight: weight ?? this.weight,
    dimensions: dimensions ?? this.dimensions,
    origin: origin ?? this.origin,
    treatments: treatments ?? this.treatments,
  );

  Map<String, dynamic> toJson() => {'species': species, 'variety': variety, 'weight': weight, 'dimensions': dimensions, 'origin': origin, 'treatments': treatments};
}

enum EvidenceDocumentType {
  laboratoryReport,
  provenanceDocument,
  custodyRecord,
  other;

  String get displayName {
    switch (this) {
      case EvidenceDocumentType.laboratoryReport: return 'Laboratory Report';
      case EvidenceDocumentType.provenanceDocument: return 'Provenance Document';
      case EvidenceDocumentType.custodyRecord: return 'Custody Record';
      case EvidenceDocumentType.other: return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case EvidenceDocumentType.laboratoryReport: return 'laboratory_report';
      case EvidenceDocumentType.provenanceDocument: return 'provenance_document';
      case EvidenceDocumentType.custodyRecord: return 'custody_record';
      case EvidenceDocumentType.other: return 'other';
    }
  }
}

class EvidenceDocument {
  final String filePath;
  final String fileName;
  final EvidenceDocumentType docType;
  final bool uploaded;
  const EvidenceDocument({required this.filePath, required this.fileName, required this.docType, this.uploaded = false});
  EvidenceDocument copyWith({String? filePath, String? fileName, EvidenceDocumentType? docType, bool? uploaded}) => EvidenceDocument(
    filePath: filePath ?? this.filePath,
    fileName: fileName ?? this.fileName,
    docType: docType ?? this.docType,
    uploaded: uploaded ?? this.uploaded,
  );
}

class SubmissionDraft {
  final String? submissionId;
  final String? orderId;
  final int step;
  final ServiceTier? selectedTier;
  final String assetName;
  final String assetType;
  final GemstoneAttributes gemstoneAttributes;
  final List<String> photoPaths;
  final List<EvidenceDocument> documents;
  final bool declaredAccurate;
  final bool declaredTierMayDiffer;
  final bool declaredTermsAgreed;

  const SubmissionDraft({
    this.submissionId,
    this.orderId,
    this.step = 0,
    this.selectedTier,
    this.assetName = '',
    this.assetType = '',
    this.gemstoneAttributes = const GemstoneAttributes(),
    this.photoPaths = const [],
    this.documents = const [],
    this.declaredAccurate = false,
    this.declaredTierMayDiffer = false,
    this.declaredTermsAgreed = false,
  });

  SubmissionDraft copyWith({String? submissionId, String? orderId, int? step, ServiceTier? selectedTier, String? assetName, String? assetType, GemstoneAttributes? gemstoneAttributes, List<String>? photoPaths, List<EvidenceDocument>? documents, bool? declaredAccurate, bool? declaredTierMayDiffer, bool? declaredTermsAgreed}) => SubmissionDraft(
    submissionId: submissionId ?? this.submissionId,
    orderId: orderId ?? this.orderId,
    step: step ?? this.step,
    selectedTier: selectedTier ?? this.selectedTier,
    assetName: assetName ?? this.assetName,
    assetType: assetType ?? this.assetType,
    gemstoneAttributes: gemstoneAttributes ?? this.gemstoneAttributes,
    photoPaths: photoPaths ?? this.photoPaths,
    documents: documents ?? this.documents,
    declaredAccurate: declaredAccurate ?? this.declaredAccurate,
    declaredTierMayDiffer: declaredTierMayDiffer ?? this.declaredTierMayDiffer,
    declaredTermsAgreed: declaredTermsAgreed ?? this.declaredTermsAgreed,
  );

  bool get declarationsComplete => declaredAccurate && declaredTierMayDiffer && declaredTermsAgreed;
}

class SubmissionQuote {
  final String serviceCode;
  final String tier;
  final String serviceDescription;
  final double price;
  final String currency;
  final String priceVersion;
  final String csaVersion;
  final bool paymentRequired;
  final int turnaroundDays;

  const SubmissionQuote({
    required this.serviceCode,
    required this.tier,
    required this.serviceDescription,
    required this.price,
    required this.currency,
    required this.priceVersion,
    required this.csaVersion,
    required this.paymentRequired,
    this.turnaroundDays = 0,
  });

  factory SubmissionQuote.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    final serviceCode = data['service_code'] as String? ?? '';
    final tier = data['tier'] as String? ?? '';
    final amountCents = (data['base_fee_cents'] as num?)?.toDouble() ?? 0;
    final description = data['service_description'] as String? ?? _descriptionFor(serviceCode, tier);
    return SubmissionQuote(
      serviceCode: serviceCode,
      tier: tier,
      serviceDescription: description,
      price: amountCents / 100,
      currency: data['currency'] as String? ?? 'USD',
      priceVersion: data['price_version'] as String? ?? '',
      csaVersion: data['csa_version'] as String? ?? '',
      paymentRequired: data['payment_required'] as bool? ?? amountCents > 0,
      turnaroundDays: (data['estimated_turnaround_days'] as num?)?.toInt() ?? 0,
    );
  }

  static String _descriptionFor(String serviceCode, String tier) {
    switch (serviceCode) {
      case 'T1_FREE_ASSET_FINGERPRINT': return 'Verified Claimant + Asset Fingerprint';
      case 'T2_DECLARED_SOURCE': return 'Declared Source Record';
      case 'T3_EVIDENCE_VERIFIED': return 'Evidence-Verified Provenance';
      case 'T4_PV_GOLD_SEAL': return 'PROVENANCE VERIFIED™ Gold Seal Review';
      default: return tier.isEmpty ? 'PROVENANCE VERIFIED service' : '$tier service';
    }
  }
}
