// Activity models — submission status tracking.
//
// All status data is server-authoritative.
// The client displays what the backend reports; it makes no trust claims.

// ---------------------------------------------------------------------------
// Credential lifecycle — server-reported registry credential state.
// Sourced from pv_review_cases via DB-authoritative tenant+asset linkage (PR #48).
// REGISTRY_STATE_ONLY = TRUE: lifecycle is a separate authority plane from
// determination tier, settlement, and Gold Seal authority.
// NOT_ISSUED does not mean trust failure — no active issued credential only.
// MTA-1: SERVER DETERMINES TRUST — sourced exclusively from the server.
// ---------------------------------------------------------------------------

enum CredentialLifecycleStatus {
  active,
  suspended,
  revoked,
  expired,
  superseded,
  notIssued,
  // R32: explicit fail-closed variant for credential/registry authority failure.
  // CREDENTIAL_AUTHORITY_UNAVAILABLE must NOT become notIssued/neutral/allow.
  // Render bounded unavailable + retry. Never permit reliance from this state.
  authorityUnavailable;

  // forward-compat: unknown API strings fail-closed to notIssued.
  // AUTHORITY_UNAVAILABLE strings map to authorityUnavailable (distinct fail-closed).
  // Null input = determination not yet available; returns null.
  static CredentialLifecycleStatus? fromApiString(String? raw) {
    if (raw == null) return null;
    switch (raw.toUpperCase()) {
      case 'ACTIVE':     return CredentialLifecycleStatus.active;
      case 'SUSPENDED':  return CredentialLifecycleStatus.suspended;
      case 'REVOKED':    return CredentialLifecycleStatus.revoked;
      case 'EXPIRED':    return CredentialLifecycleStatus.expired;
      case 'SUPERSEDED': return CredentialLifecycleStatus.superseded;
      case 'NOT_ISSUED': return CredentialLifecycleStatus.notIssued;
      case 'CREDENTIAL_AUTHORITY_UNAVAILABLE':
      case 'REGISTRY_AUTHORITY_UNAVAILABLE':
        return CredentialLifecycleStatus.authorityUnavailable;
      default:           return CredentialLifecycleStatus.notIssued;
    }
  }

  String get displayLabel {
    switch (this) {
      case CredentialLifecycleStatus.active:               return 'Credential Active';
      case CredentialLifecycleStatus.suspended:            return 'Credential Suspended';
      case CredentialLifecycleStatus.revoked:              return 'Credential Revoked';
      case CredentialLifecycleStatus.expired:              return 'Credential Expired';
      case CredentialLifecycleStatus.superseded:           return 'Credential Superseded';
      case CredentialLifecycleStatus.notIssued:            return 'No Active Credential';
      case CredentialLifecycleStatus.authorityUnavailable: return 'Credential Authority Unavailable';
    }
  }
}

// ---------------------------------------------------------------------------
// Settlement payment status — server-reported payment lifecycle state.
// MONEY_CONTROLS_TRUST = FALSE: this field is informational only.
// Scoped to the authenticated customer; never projected as trust state.
// ---------------------------------------------------------------------------

enum SettlementPaymentStatus {
  free,
  paid,
  pending,
  // R32: explicit fail-closed variant for settlement authority lookup failure.
  // LOOKUP_ERROR is NOT equivalent to unknown/null/pending.
  // No settle CTA, no checkout, no Public Verify/reliance unlock on LOOKUP_ERROR.
  lookupError,
  unknown;

  static SettlementPaymentStatus? fromApiString(String? raw) {
    if (raw == null) return null;
    switch (raw.toUpperCase()) {
      case 'FREE':         return SettlementPaymentStatus.free;
      case 'PAID':         return SettlementPaymentStatus.paid;
      case 'PENDING':      return SettlementPaymentStatus.pending;
      case 'LOOKUP_ERROR': return SettlementPaymentStatus.lookupError;
      default:             return SettlementPaymentStatus.unknown;
    }
  }

  String get displayLabel {
    switch (this) {
      case SettlementPaymentStatus.free:        return 'Settled (Free)';
      case SettlementPaymentStatus.paid:        return 'Settled (Paid)';
      case SettlementPaymentStatus.pending:     return 'Awaiting Settlement';
      case SettlementPaymentStatus.lookupError: return 'Settlement Unavailable';
      case SettlementPaymentStatus.unknown:     return 'Unknown';
    }
  }
}

// ---------------------------------------------------------------------------
// Status codes
// ---------------------------------------------------------------------------

enum SubmissionStatus {
  submitted,
  paymentConfirmed,
  awaitingShipment,
  inTransit,
  received,
  intakeComplete,
  evidenceReview,
  moreInformationRequired,
  additionalInfoRequested,
  determination,
  issuancePending,
  issued,
  returnInTransit,
  closed,
  unknown;

  /// Maps the raw API string to the enum value.
  static SubmissionStatus fromApiString(String raw) {
    switch (raw.toUpperCase()) {
      case 'SUBMITTED':                  return SubmissionStatus.submitted;
      case 'PAYMENT_CONFIRMED':          return SubmissionStatus.paymentConfirmed;
      case 'AWAITING_SHIPMENT':          return SubmissionStatus.awaitingShipment;
      case 'IN_TRANSIT':                 return SubmissionStatus.inTransit;
      case 'RECEIVED':                   return SubmissionStatus.received;
      case 'INTAKE_COMPLETE':            return SubmissionStatus.intakeComplete;
      case 'EVIDENCE_REVIEW':            return SubmissionStatus.evidenceReview;
      case 'MORE_INFORMATION_REQUIRED':  return SubmissionStatus.moreInformationRequired;
      case 'ADDITIONAL_INFO_REQUESTED':  return SubmissionStatus.additionalInfoRequested;
      case 'DETERMINATION':              return SubmissionStatus.determination;
      case 'ISSUANCE_PENDING':           return SubmissionStatus.issuancePending;
      case 'ISSUED':                     return SubmissionStatus.issued;
      case 'RETURN_IN_TRANSIT':          return SubmissionStatus.returnInTransit;
      case 'CLOSED':                     return SubmissionStatus.closed;
      default:                           return SubmissionStatus.unknown;
    }
  }

  /// Human-readable label for display.
  String get displayLabel {
    switch (this) {
      case SubmissionStatus.submitted:               return 'Submitted';
      case SubmissionStatus.paymentConfirmed:        return 'Payment Confirmed';
      case SubmissionStatus.awaitingShipment:        return 'Awaiting Shipment';
      case SubmissionStatus.inTransit:               return 'In Transit';
      case SubmissionStatus.received:                return 'Received';
      case SubmissionStatus.intakeComplete:          return 'Intake Complete';
      case SubmissionStatus.evidenceReview:          return 'Evidence Review';
      case SubmissionStatus.moreInformationRequired: return 'More Information Required';
      case SubmissionStatus.additionalInfoRequested: return 'Additional Info Requested';
      case SubmissionStatus.determination:           return 'Determination';
      case SubmissionStatus.issuancePending:         return 'Issuance Pending';
      case SubmissionStatus.issued:                  return 'Issued';
      case SubmissionStatus.returnInTransit:         return 'Return in Transit';
      case SubmissionStatus.closed:                  return 'Closed';
      case SubmissionStatus.unknown:                 return 'Unknown';
    }
  }

  /// API string value for this status.
  String get apiString {
    switch (this) {
      case SubmissionStatus.submitted:               return 'SUBMITTED';
      case SubmissionStatus.paymentConfirmed:        return 'PAYMENT_CONFIRMED';
      case SubmissionStatus.awaitingShipment:        return 'AWAITING_SHIPMENT';
      case SubmissionStatus.inTransit:               return 'IN_TRANSIT';
      case SubmissionStatus.received:                return 'RECEIVED';
      case SubmissionStatus.intakeComplete:          return 'INTAKE_COMPLETE';
      case SubmissionStatus.evidenceReview:          return 'EVIDENCE_REVIEW';
      case SubmissionStatus.moreInformationRequired: return 'MORE_INFORMATION_REQUIRED';
      case SubmissionStatus.additionalInfoRequested: return 'ADDITIONAL_INFO_REQUESTED';
      case SubmissionStatus.determination:           return 'DETERMINATION';
      case SubmissionStatus.issuancePending:         return 'ISSUANCE_PENDING';
      case SubmissionStatus.issued:                  return 'ISSUED';
      case SubmissionStatus.returnInTransit:         return 'RETURN_IN_TRANSIT';
      case SubmissionStatus.closed:                  return 'CLOSED';
      case SubmissionStatus.unknown:                 return 'UNKNOWN';
    }
  }
}

// ---------------------------------------------------------------------------
// SubmissionStatusItem — list view row model
// ---------------------------------------------------------------------------

class SubmissionStatusItem {
  final String submissionId;
  final SubmissionStatus status;
  final String assetName;
  // Decode-only: retained for backward-compat JSON parsing only.
  // Must not be projected as current trust authority or displayed as tier state.
  final String requestedServiceTier;
  /// The tier that the server determined — null until determination is complete.
  /// CUSTOMER_SELECTS_TIER = FALSE: this value comes exclusively from the server.
  final String? determinedTier;
  final DateTime updatedAt;
  final bool hasEvidenceRequest;
  /// Settlement payment status — null when settlement has not occurred.
  /// MONEY_CONTROLS_TRUST = FALSE: this is billing state only.
  final SettlementPaymentStatus? settlementPaymentStatus;

  const SubmissionStatusItem({
    required this.submissionId,
    required this.status,
    required this.assetName,
    required this.requestedServiceTier,
    this.determinedTier,
    required this.updatedAt,
    required this.hasEvidenceRequest,
    this.settlementPaymentStatus,
  });

  factory SubmissionStatusItem.fromJson(Map<String, dynamic> json) {
    return SubmissionStatusItem(
      submissionId:        json['submission_id'] as String? ?? '',
      status:              SubmissionStatus.fromApiString(
                             json['status'] as String? ?? ''),
      assetName:           json['asset_name'] as String? ?? 'Unnamed',
      requestedServiceTier: json['requested_service_tier'] as String? ?? '',
      determinedTier:      json['determined_tier'] as String?,
      updatedAt:           DateTime.tryParse(
                             json['updated_at'] as String? ?? '') ??
                           DateTime.now(),
      hasEvidenceRequest:  json['has_evidence_request'] as bool? ?? false,
      settlementPaymentStatus: SettlementPaymentStatus.fromApiString(
                             json['settlement_payment_status'] as String?),
    );
  }
}

// ---------------------------------------------------------------------------
// Custody event — timeline entry in detail view
// ---------------------------------------------------------------------------

class CustodyEvent {
  final String eventType;
  final String description;
  final DateTime timestamp;

  const CustodyEvent({
    required this.eventType,
    required this.description,
    required this.timestamp,
  });

  factory CustodyEvent.fromJson(Map<String, dynamic> json) {
    return CustodyEvent(
      eventType:   json['event_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp:   DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                   DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Settlement — server-authored order/settlement data from data.settlement.
// Authority seam added in PR #47. Null key = old API (fail-closed).
// MONEY_CONTROLS_TRUST = FALSE: payment state is informational only.
// MTA-1: SERVER DETERMINES TRUST — this object comes from the server.
// ---------------------------------------------------------------------------

class Settlement {
  final String orderId;
  final String paymentStatus;
  final String? serviceTier;
  final int? amountCents;
  final String? currency;
  final DateTime? settledAt;

  const Settlement({
    required this.orderId,
    required this.paymentStatus,
    this.serviceTier,
    this.amountCents,
    this.currency,
    this.settledAt,
  });

  // Returns true when settlement is complete: FREE or PAID.
  // MONEY_CONTROLS_TRUST = FALSE: isSettled gates record presentation,
  // not trust tier authority.
  bool get isSettled {
    final s = paymentStatus.toUpperCase();
    return s == 'FREE' || s == 'PAID';
  }

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        orderId:       j['orderId'] as String? ?? '',
        paymentStatus: j['paymentStatus'] as String? ?? '',
        serviceTier:   j['serviceTier'] as String?,
        amountCents:   j['amountCents'] as int?,
        currency:      j['currency'] as String?,
        settledAt:     j['settledAt'] != null
            ? DateTime.tryParse(j['settledAt'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// TrustCurrentness — R32: PR47 server-authored lifecycle/currentness object.
// Consumed from customer submission status endpoint when key 'trust_currentness'
// is present. MTA-1: SERVER DETERMINES TRUST.
// LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY.
// credential_state here is the PR47 customer-operating-plane view, separate from
// the credentialLifecycle registry plane. NOT_ISSUED ≠ trust failure.
// ---------------------------------------------------------------------------

class TrustCurrentness {
  final String? determinationState;
  final bool? determinationIsCurrent;
  final DateTime? computedAt;
  final String? requeryGuidance;
  final String? relianceBoundary;
  final String? authorityNote;
  final String? credentialState;

  const TrustCurrentness({
    this.determinationState,
    this.determinationIsCurrent,
    this.computedAt,
    this.requeryGuidance,
    this.relianceBoundary,
    this.authorityNote,
    this.credentialState,
  });

  bool get hasAuthorityUnavailable {
    final s = (determinationState ?? '').toUpperCase();
    return s.contains('UNAVAILABLE');
  }

  factory TrustCurrentness.fromJson(Map<String, dynamic> j) => TrustCurrentness(
        determinationState:     j['determination_state'] as String?,
        determinationIsCurrent: j['determination_is_current'] as bool?,
        computedAt: j['computed_at'] != null
            ? DateTime.tryParse(j['computed_at'] as String)
            : null,
        requeryGuidance:  j['requery_guidance'] as String?,
        relianceBoundary: j['reliance_boundary'] as String?,
        authorityNote:    j['authority_note'] as String?,
        credentialState:  j['credential_state'] as String?,
      );
}

// ---------------------------------------------------------------------------
// SubmissionDetail — full detail returned by GET .../status
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// DeterminationResult — server-authored determination data embedded in detail
// ---------------------------------------------------------------------------

class DeterminationResult {
  /// Tier assigned by the server. CUSTOMER_SELECTS_TIER = FALSE.
  final String tier;
  final String? serviceCode;
  final String? whyThisTier;
  final String? whyNotNextTier;
  final List<String> limitations;

  const DeterminationResult({
    required this.tier,
    this.serviceCode,
    this.whyThisTier,
    this.whyNotNextTier,
    this.limitations = const [],
  });

  factory DeterminationResult.fromJson(Map<String, dynamic> j) {
    return DeterminationResult(
      tier:          j['determined_tier'] as String? ?? j['tier'] as String? ?? '',
      serviceCode:   j['service_code'] as String?,
      whyThisTier:   j['why_this_tier'] is List
          ? (j['why_this_tier'] as List).join(' ')
          : j['why_this_tier']?.toString(),
      whyNotNextTier: (j['why_not_higher'] ?? j['why_not_next_tier'])?.toString(),
      limitations: (j['limitations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

// ---------------------------------------------------------------------------
// SubmissionDetail — full detail returned by GET .../status
// ---------------------------------------------------------------------------

class SubmissionDetail {
  final String submissionId;
  final SubmissionStatus status;
  final String assetName;
  // Decode-only: retained for backward-compat JSON parsing only.
  // Must not be projected as current trust authority or displayed as tier state.
  final String requestedServiceTier;
  final String? evidenceRequestInstructions;
  final String? issuedAssetId;     // set when status == ISSUED
  final List<CustodyEvent> custodyEvents;
  final DateTime updatedAt;
  /// Server-authored determination. Populated after the determination step.
  /// Null when determination has not yet been completed.
  final DeterminationResult? determination;
  /// Public provenance record ID, set when determination is complete and
  /// a registry record exists. MTA-1: SERVER DETERMINES TRUST — this value
  /// comes from the server; native only displays it.
  final String? publicId;
  /// Timestamp when the determination was computed by the server.
  final DateTime? determinedAt;
  /// Settlement payment status — null when settlement has not occurred.
  /// MONEY_CONTROLS_TRUST = FALSE: this is billing state only.
  final SettlementPaymentStatus? settlementPaymentStatus;
  // Settlement authority from data.settlement (PR #47 explicit seam, R29).
  // hasSettlementSeam = true iff server returned the 'settlement' key.
  // Key-absent (old API) → false → fail-closed. Key-present-null → seam active, no order yet.
  // MONEY_CONTROLS_TRUST = FALSE.
  final bool hasSettlementSeam;
  final Settlement? settlementData;
  /// Credential registry lifecycle state — null when determination is not yet
  /// complete or when asset/tenant coordinates are unavailable.
  /// REGISTRY_STATE_ONLY = TRUE: NOT_ISSUED ≠ trust failure.
  /// MTA-1: SERVER DETERMINES TRUST — sourced from pv_review_cases (PR #48).
  final CredentialLifecycleStatus? credentialLifecycle;
  /// PR47 server-authored trust currentness object — null when not present.
  /// MTA-1: SERVER DETERMINES TRUST. LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY.
  final TrustCurrentness? trustCurrentness;

  const SubmissionDetail({
    required this.submissionId,
    required this.status,
    required this.assetName,
    required this.requestedServiceTier,
    this.evidenceRequestInstructions,
    this.issuedAssetId,
    required this.custodyEvents,
    required this.updatedAt,
    this.determination,
    this.publicId,
    this.determinedAt,
    this.settlementPaymentStatus,
    this.hasSettlementSeam = false,
    this.settlementData,
    this.credentialLifecycle,
    this.trustCurrentness,
  });

  factory SubmissionDetail.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['custody_events'] as List<dynamic>? ?? [];
    // Determination may be nested under 'determination' key or at top level
    // when the backend inlines it.
    DeterminationResult? det;
    final detRaw = json['determination'];
    if (detRaw is Map<String, dynamic> && detRaw.isNotEmpty) {
      det = DeterminationResult.fromJson(detRaw);
    } else if (json['determined_tier'] != null) {
      det = DeterminationResult.fromJson(json);
    }
    return SubmissionDetail(
      submissionId:                json['submission_id'] as String? ?? '',
      status:                      SubmissionStatus.fromApiString(
                                     json['status'] as String? ?? ''),
      assetName:                   json['asset_name'] as String? ?? 'Unnamed',
      requestedServiceTier:        json['requested_service_tier'] as String? ?? '',
      evidenceRequestInstructions: json['evidence_request_instructions'] as String?,
      issuedAssetId:               json['issued_asset_id'] as String?,
      custodyEvents:               rawEvents
                                     .map((e) => CustodyEvent.fromJson(
                                           e as Map<String, dynamic>))
                                     .toList(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
                 DateTime.now(),
      determination: det,
      publicId:    json['public_id'] as String?,
      determinedAt: DateTime.tryParse(json['determined_at'] as String? ?? ''),
      settlementPaymentStatus: SettlementPaymentStatus.fromApiString(
                               json['settlement_payment_status'] as String?),
      hasSettlementSeam: json.containsKey('settlement'),
      settlementData: json.containsKey('settlement') && json['settlement'] is Map<String, dynamic>
          ? Settlement.fromJson(json['settlement'] as Map<String, dynamic>)
          : null,
      credentialLifecycle: CredentialLifecycleStatus.fromApiString(
                           json['credential_lifecycle'] as String?),
      trustCurrentness: json.containsKey('trust_currentness') &&
              json['trust_currentness'] is Map<String, dynamic>
          ? TrustCurrentness.fromJson(
                json['trust_currentness'] as Map<String, dynamic>)
          : null,
    );
  }
}
