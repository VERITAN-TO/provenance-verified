// Submit models — gemstone certification submission workflow.
//
// MONEY_CONTROLS_TRUST = FALSE
// Customer-selected tier is a REQUESTED SERVICE, not a guaranteed outcome.
// The determined trust tier is set exclusively by the backend after review.

// ---------------------------------------------------------------------------
// Service tiers (requested, not guaranteed)
// ---------------------------------------------------------------------------

enum ServiceTier {
  /// T1 — Free basic provenance record.
  t1Free,

  /// T2 — Standard review with document examination.
  t2Standard,

  /// T3 — Professional review with laboratory liaison.
  t3Professional,

  /// T4 — Full certification with physical examination.
  t4Certified;

  String get displayName {
    switch (this) {
      case ServiceTier.t1Free:          return 'T1 Free';
      case ServiceTier.t2Standard:      return 'T2 Standard';
      case ServiceTier.t3Professional:  return 'T3 Professional';
      case ServiceTier.t4Certified:     return 'T4 Certified';
    }
  }

  String get apiValue {
    switch (this) {
      case ServiceTier.t1Free:          return 'T1_FREE';
      case ServiceTier.t2Standard:      return 'T2_STANDARD';
      case ServiceTier.t3Professional:  return 'T3_PROFESSIONAL';
      case ServiceTier.t4Certified:     return 'T4_CERTIFIED';
    }
  }

  String get priceRange {
    switch (this) {
      case ServiceTier.t1Free:          return 'Free';
      case ServiceTier.t2Standard:      return '\$49 – \$149';
      case ServiceTier.t3Professional:  return '\$249 – \$599';
      case ServiceTier.t4Certified:     return '\$799 – \$1,999';
    }
  }

  String get shortDescription {
    switch (this) {
      case ServiceTier.t1Free:
        return 'Basic provenance record. No document examination.';
      case ServiceTier.t2Standard:
        return 'Standard review with document and evidence examination.';
      case ServiceTier.t3Professional:
        return 'Professional review including laboratory report liaison.';
      case ServiceTier.t4Certified:
        return 'Full certification with physical examination by our team.';
    }
  }

  List<String> get features {
    switch (this) {
      case ServiceTier.t1Free:
        return [
          'Provenance record created',
          'QR code issued on completion',
          'No document examination',
        ];
      case ServiceTier.t2Standard:
        return [
          'Document examination included',
          'Evidence review by trained staff',
          'QR code issued on completion',
          '10–15 business-day turnaround',
        ];
      case ServiceTier.t3Professional:
        return [
          'All Standard features',
          'Laboratory report cross-verification',
          'Specialist gemologist review',
          '7–10 business-day turnaround',
        ];
      case ServiceTier.t4Certified:
        return [
          'All Professional features',
          'Physical gemstone examination',
          'Custody tracking throughout',
          'Priority processing (3–5 business days)',
          'Highest trust determination possible',
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// Gemstone attributes declared by the submitter
// ---------------------------------------------------------------------------

class GemstoneAttributes {
  final String species;     // e.g. Corundum, Beryl
  final String variety;     // e.g. Ruby, Emerald
  final String weight;      // e.g. "3.45 ct"
  final String dimensions;  // e.g. "9.2 × 7.1 × 4.3 mm"
  final String origin;      // e.g. "Mogok, Myanmar (declared)"
  final String treatments;  // e.g. "None declared", "Heat treated (declared)"

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
  }) =>
      GemstoneAttributes(
        species:    species    ?? this.species,
        variety:    variety    ?? this.variety,
        weight:     weight     ?? this.weight,
        dimensions: dimensions ?? this.dimensions,
        origin:     origin     ?? this.origin,
        treatments: treatments ?? this.treatments,
      );

  Map<String, dynamic> toJson() => {
        'species':    species,
        'variety':    variety,
        'weight':     weight,
        'dimensions': dimensions,
        'origin':     origin,
        'treatments': treatments,
      };
}

// ---------------------------------------------------------------------------
// Evidence document (for upload step)
// ---------------------------------------------------------------------------

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
  final String filePath;      // local path before upload
  final String fileName;
  final EvidenceDocumentType docType;
  final bool uploaded;        // true once confirmed uploaded to server

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
  }) =>
      EvidenceDocument(
        filePath:  filePath  ?? this.filePath,
        fileName:  fileName  ?? this.fileName,
        docType:   docType   ?? this.docType,
        uploaded:  uploaded  ?? this.uploaded,
      );
}

// ---------------------------------------------------------------------------
// Submission draft — wizard state
// ---------------------------------------------------------------------------

class SubmissionDraft {
  final String? submissionId;
  final String? orderId;
  final int step;

  // Step 0 — service selection
  final ServiceTier? selectedTier;

  // Step 1 — asset information
  final String assetName;
  final String assetType;
  final GemstoneAttributes gemstoneAttributes;

  // Step 1b — photos (file paths, not yet uploaded as evidence)
  final List<String> photoPaths;

  // Step 2 — evidence documents
  final List<EvidenceDocument> documents;

  // Step 3 — declarations
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
  }) =>
      SubmissionDraft(
        submissionId:         submissionId        ?? this.submissionId,
        orderId:              orderId             ?? this.orderId,
        step:                 step                ?? this.step,
        selectedTier:         selectedTier        ?? this.selectedTier,
        assetName:            assetName           ?? this.assetName,
        assetType:            assetType           ?? this.assetType,
        gemstoneAttributes:   gemstoneAttributes  ?? this.gemstoneAttributes,
        photoPaths:           photoPaths          ?? this.photoPaths,
        documents:            documents           ?? this.documents,
        declaredAccurate:     declaredAccurate    ?? this.declaredAccurate,
        declaredTierMayDiffer: declaredTierMayDiffer ?? this.declaredTierMayDiffer,
        declaredTermsAgreed:  declaredTermsAgreed ?? this.declaredTermsAgreed,
      );

  bool get declarationsComplete =>
      declaredAccurate && declaredTierMayDiffer && declaredTermsAgreed;
}

// ---------------------------------------------------------------------------
// Quote returned by GET /api/v1/customer/submissions/:id/quote
// ---------------------------------------------------------------------------

class SubmissionQuote {
  final String submissionId;
  final String serviceDescription;
  final double price;
  final String currency;
  final int turnaroundDays;

  const SubmissionQuote({
    required this.submissionId,
    required this.serviceDescription,
    required this.price,
    required this.currency,
    required this.turnaroundDays,
  });

  factory SubmissionQuote.fromJson(Map<String, dynamic> json) {
    return SubmissionQuote(
      submissionId:       json['submission_id'] as String? ?? '',
      serviceDescription: json['service_description'] as String? ?? '',
      price:              (json['price'] as num?)?.toDouble() ?? 0.0,
      currency:           json['currency'] as String? ?? 'USD',
      turnaroundDays:     json['turnaround_days'] as int? ?? 0,
    );
  }
}
