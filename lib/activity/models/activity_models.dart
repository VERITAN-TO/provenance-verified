// Activity models — submission status tracking.
//
// All status data is server-authoritative.
// The client displays what the backend reports; it makes no trust claims.

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
  final String requestedServiceTier; // what the customer requested
  final DateTime updatedAt;
  final bool hasEvidenceRequest;

  const SubmissionStatusItem({
    required this.submissionId,
    required this.status,
    required this.assetName,
    required this.requestedServiceTier,
    required this.updatedAt,
    required this.hasEvidenceRequest,
  });

  factory SubmissionStatusItem.fromJson(Map<String, dynamic> json) {
    return SubmissionStatusItem(
      submissionId:        json['submission_id'] as String? ?? '',
      status:              SubmissionStatus.fromApiString(
                             json['status'] as String? ?? ''),
      assetName:           json['asset_name'] as String? ?? 'Unnamed',
      requestedServiceTier: json['requested_service_tier'] as String? ?? '',
      updatedAt:           DateTime.tryParse(
                             json['updated_at'] as String? ?? '') ??
                           DateTime.now(),
      hasEvidenceRequest:  json['has_evidence_request'] as bool? ?? false,
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
// SubmissionDetail — full detail returned by GET .../status
// ---------------------------------------------------------------------------

class SubmissionDetail {
  final String submissionId;
  final SubmissionStatus status;
  final String assetName;
  final String requestedServiceTier;
  final String? evidenceRequestInstructions;
  final String? issuedAssetId;     // set when status == ISSUED
  final List<CustodyEvent> custodyEvents;
  final DateTime updatedAt;

  const SubmissionDetail({
    required this.submissionId,
    required this.status,
    required this.assetName,
    required this.requestedServiceTier,
    this.evidenceRequestInstructions,
    this.issuedAssetId,
    required this.custodyEvents,
    required this.updatedAt,
  });

  factory SubmissionDetail.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['custody_events'] as List<dynamic>? ?? [];
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
    );
  }
}
