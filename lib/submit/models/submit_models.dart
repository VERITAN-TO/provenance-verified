// Submit models — gemstone certification submission workflow.
//
// MONEY_CONTROLS_TRUST = FALSE
// Customer-selected tier is a REQUESTED SERVICE, not a guaranteed outcome.
// The determined trust state is set exclusively by the governed backend after review.

enum ServiceTier {
  t1Free,
  t2Standard,
  t3Professional,
  t4Certified;

  String get displayName {
    switch (this) {
      case ServiceTier.t1Free:         return 'T1 — Asset Fingerprint';
      case ServiceTier.t2Standard:     return 'T2 — Declared Source Record';
      case ServiceTier.t3Professional: return 'T3 — Evidence-Verified Provenance';
      case ServiceTier.t4Certified:    return 'T4 — PV Gold Seal';
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
        return 'Public-anchored asset fingerprint. No source claims or evidence review.';
      case ServiceTier.t2Standard:
        return 'Independent documented record of declared source information.';
      case ServiceTier.t3Professional:
        return 'Expert-reviewed provenance with evidence evaluation and custody documentation.';
      case ServiceTier.t4Certified:
        return 'Highest service tier with multi-source evidence review and custody audit.';
    }
  }

  List<String> get features {
    switch (this) {
      case ServiceTier.t1Free:
        return [
          'Asset fingerprint record',
          'Public verification reference when authorized',
          'No provenance claim is inferred',
        ];
      case ServiceTier.t2Standard:
        return [
          'Declared source information recorded',
          'Document and evidence review',
          'Customer-visible case status',
        ];
      case ServiceTier.t3Professional:
        return [
          'Evidence evaluation',
          'Chain-of-custody documentation',
          'Expert review',
        ];
      case ServiceTier.t4Certified:
        return [
          'Multi-source evidence review',
          'Chain-of-custody audit',
          'Physical examination where required by the operating protocol',
          'Any trust or mark outcome remains independently determined',
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

  const GemstoneAttributes({
    this.species = '',
    this.variety = '',
    this.weight = '',
    this.dimensions = '',
    this.origin = '',
    this.treatments = '',
  });

  GemstoneAttributes copyWith({
    String? species,
    String? variety,
    String? weight,
    String? dimensions,
    String? origin,
    String? treatments,
  }) => GemstoneAttributes(
    species: species ?? this.species,
    variety: variety ?? this.variety,
    weight: weight ?? this.weight,
    dimensions: dimensions ?? this.dimensions,
    origin: origin ?? this.origin,
    treatments: treatments ?? this.treatments,
  );

  Map<String, dynamic> toJson() => {
    'species': species,
    'variety': variety,
    'weight': weight,
    'dimensions': dimensions,
    'origin': origin,
    'treatments': treatments,
  };
}

enum EvidenceDocumentType {
  laboratoryReport,
  provenanceDocument,
  custodyRecord,
  other;

  String get displayName {
    switch (this) {
      case EvidenceDocumentType.laboratoryReport:   return 'Laboratory Report';
      case EvidenceDocumentType.provenanceDocument: return 'Provenance Document';
      case EvidenceDocumentType.custodyRecord:      return 'Custody Record';
      case EvidenceDocumentType.other:              return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case EvidenceDocumentType.laboratoryReport:   return 'laboratory_report';
      case EvidenceDocumentType.provenanceDocument: return 'provenance_document';
      case EvidenceDocumentType.custodyRecord:      return 'custody_record';
      case EvidenceDocumentType.other:              return 'other';
    }
  }
}

class EvidenceDocument {
  final String filePath;
  final String fileName;
  final EvidenceDocumentType docType;
  final bool uploaded;

  const EvidenceDocument({
    required this.filePath,
    required this.fileName,
    required this.docType,
    this.uploaded = false,
  });

  EvidenceDocument copyWith({
    String? filePath,
    String? fileName,
    EvidenceDocumentType? docType,
    bool? uploaded,
  }) => EvidenceDocument(
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

  SubmissionDraft copyWith({
    String? submissionId,
    String? orderId,
    int? step,
    ServiceTier? selectedTier,
    String? assetName,
    String? assetType,
    GemstoneAttributes? gemstoneAttributes,
    List<String>? photoPaths,
    List<EvidenceDocument>? documents,
    bool? declaredAccurate,
    bool? declaredTierMayDiffer,
    bool? declaredTermsAgreed,
  }) => SubmissionDraft(
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

  const SubmissionQuote({
    required this.serviceCode,
    required this.tier,
    required this.serviceDescription,
    required this.price,
    required this.currency,
    required this.priceVersion,
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
    );
  }

  static String _descriptionFor(String serviceCode, String tier) {
    switch (serviceCode) {
      case 'T1_FREE_ASSET_FINGERPRINT': return 'Asset Fingerprint';
      case 'T2_DECLARED_SOURCE': return 'Declared Source Record';
      case 'T3_EVIDENCE_VERIFIED': return 'Evidence-Verified Provenance';
      case 'T4_PV_GOLD_SEAL': return 'PV Gold Seal';
      default: return tier.isEmpty ? 'PROVENANCE VERIFIED service' : '$tier service';
    }
  }
}
