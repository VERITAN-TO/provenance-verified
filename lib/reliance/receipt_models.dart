// M2: Reliance receipt model — supports both server-issued and local receipts.
// Server-issued receipts: isServerIssued=true, receiptId from server.
// Local receipts: isServerIssued=false, receiptId from UUID v4.
// trust_state_digest is canonical — used for stale detection.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

import '../actionability/actionability_models.dart';

enum ReceiptValidityState {
  valid,
  invalidated,
  expired,
  unknown;
}

class RelianceReceipt {
  final String receiptId;
  final String publicId;
  final String physicalSubjectId;
  final String trustStateDigest;
  final ActionabilityPurpose purpose;
  final ActionabilityDecision decision;
  final List<String> limitations;
  final List<String> prohibitedInferences;
  final DateTime createdAt;
  final DateTime? validUntil;
  final ReceiptValidityState validityState;
  final String? policyVersion;
  // M2: true if receipt was issued by the PV server; false if local-only.
  final bool isServerIssued;

  const RelianceReceipt({
    required this.receiptId,
    required this.publicId,
    required this.physicalSubjectId,
    required this.trustStateDigest,
    required this.purpose,
    required this.decision,
    this.limitations = const [],
    this.prohibitedInferences = const [],
    required this.createdAt,
    this.validUntil,
    this.validityState = ReceiptValidityState.unknown,
    this.policyVersion,
    this.isServerIssued = false,
  });

  // Check if the receipt is stale: trust state has changed since issuance.
  bool isStaleFor(String currentTrustStateDigest) {
    if (trustStateDigest.isEmpty) return false;
    return trustStateDigest != currentTrustStateDigest;
  }

  // A stale receipt MUST be invalidated — never reused for reliance decisions.
  RelianceReceipt invalidate() => RelianceReceipt(
        receiptId: receiptId,
        publicId: publicId,
        physicalSubjectId: physicalSubjectId,
        trustStateDigest: trustStateDigest,
        purpose: purpose,
        decision: decision,
        limitations: limitations,
        prohibitedInferences: prohibitedInferences,
        createdAt: createdAt,
        validUntil: validUntil,
        validityState: ReceiptValidityState.invalidated,
        policyVersion: policyVersion,
        isServerIssued: isServerIssued,
      );

  Map<String, dynamic> toJson() => {
        'receipt_id': receiptId,
        'public_id': publicId,
        'physical_subject_id': physicalSubjectId,
        'trust_state_digest': trustStateDigest,
        'purpose': purpose.toJson(),
        'decision': decision.name.toUpperCase(),
        'limitations': limitations,
        'prohibited_inferences': prohibitedInferences,
        'created_at': createdAt.toIso8601String(),
        if (validUntil != null) 'valid_until': validUntil!.toIso8601String(),
        'validity_state': validityState.name.toUpperCase(),
        if (policyVersion != null) 'policy_version': policyVersion,
        'is_server_issued': isServerIssued,
      };

  factory RelianceReceipt.fromJson(Map<String, dynamic> j) => RelianceReceipt(
        receiptId: j['receipt_id'] as String? ?? '',
        publicId: j['public_id'] as String? ?? '',
        physicalSubjectId: j['physical_subject_id'] as String? ?? '',
        trustStateDigest: j['trust_state_digest'] as String? ?? '',
        purpose: ActionabilityPurpose.fromJson(j['purpose']),
        decision: ActionabilityDecision.fromJson(j['decision']),
        limitations: (j['limitations'] as List?)?.map((e) => e.toString()).toList() ?? [],
        prohibitedInferences:
            (j['prohibited_inferences'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime(2026),
        validUntil: j['valid_until'] != null
            ? DateTime.tryParse(j['valid_until'] as String)
            : null,
        validityState: _parseValidity(j['validity_state']),
        policyVersion: j['policy_version'] as String?,
        isServerIssued: j['is_server_issued'] as bool? ?? false,
      );

  static ReceiptValidityState _parseValidity(dynamic v) {
    if (v == null) return ReceiptValidityState.unknown;
    switch (v.toString().toUpperCase()) {
      case 'VALID': return ReceiptValidityState.valid;
      case 'INVALIDATED': return ReceiptValidityState.invalidated;
      case 'EXPIRED': return ReceiptValidityState.expired;
      default: return ReceiptValidityState.unknown;
    }
  }
}
