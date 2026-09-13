// Home screen models — plain Dart, no code generation.
// NOTE: Trust tier values come from the server. Mobile never determines trust.

class RecentScan {
  final String publicId;
  final int? trustTier;    // null if unqualified or unknown — never overclaim
  final bool eligible;
  final DateTime scannedAt;

  const RecentScan({
    required this.publicId,
    this.trustTier,
    required this.eligible,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'public_id': publicId,
        if (trustTier != null) 'trust_tier': trustTier,
        'eligible': eligible,
        'scanned_at': scannedAt.toUtc().toIso8601String(),
      };

  factory RecentScan.fromJson(Map<String, dynamic> j) => RecentScan(
        publicId: j['public_id'] as String? ?? '',
        trustTier: j['trust_tier'] as int?,
        eligible: j['eligible'] as bool? ?? false,
        scannedAt: j['scanned_at'] != null
            ? DateTime.tryParse(j['scanned_at'] as String) ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
      );
}

class SubmissionSummary {
  final String submissionId;
  final String status;
  final String assetName;
  final DateTime updatedAt;

  const SubmissionSummary({
    required this.submissionId,
    required this.status,
    required this.assetName,
    required this.updatedAt,
  });

  factory SubmissionSummary.fromJson(Map<String, dynamic> j) => SubmissionSummary(
        submissionId: j['submission_id'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        assetName: j['asset_name'] as String? ?? 'Unnamed asset',
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String) ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
      );
}

enum AlertType {
  trustStateChange,
  staleReceipt,
  certificationExpiring,
  submissionRequiresAction,
  unknown;

  static AlertType fromJson(dynamic v) {
    switch (v?.toString()) {
      case 'TRUST_STATE_CHANGE': return trustStateChange;
      case 'STALE_RECEIPT': return staleReceipt;
      case 'CERTIFICATION_EXPIRING': return certificationExpiring;
      case 'SUBMISSION_REQUIRES_ACTION': return submissionRequiresAction;
      default: return unknown;
    }
  }
}

class TrustAlert {
  final String alertId;
  final String? assetId;
  final String assetName;
  final AlertType alertType;
  final String message;
  final DateTime createdAt;
  final bool read;

  const TrustAlert({
    required this.alertId,
    this.assetId,
    required this.assetName,
    required this.alertType,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  factory TrustAlert.fromJson(Map<String, dynamic> j) => TrustAlert(
        alertId: j['alert_id'] as String? ?? '',
        assetId: j['asset_id'] as String?,
        assetName: j['asset_name'] as String? ?? 'Unknown asset',
        alertType: AlertType.fromJson(j['alert_type']),
        message: j['message'] as String? ?? '',
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        read: j['read'] as bool? ?? false,
      );
}
