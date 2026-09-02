// My PV models — plain Dart, no code generation.
// Trust tier values come from the server. Mobile never determines trust.

class CustomerAsset {
  final String assetId;
  final String publicId;
  final String assetName;
  final String assetType;
  final int? trustTier;         // null if unqualified — never overclaim
  final bool eligible;
  final String? currentDigest;
  final DateTime? lastVerifiedAt;
  final bool hasStaledReceipts;
  final String? imageUrl;

  const CustomerAsset({
    required this.assetId,
    required this.publicId,
    required this.assetName,
    required this.assetType,
    this.trustTier,
    required this.eligible,
    this.currentDigest,
    this.lastVerifiedAt,
    this.hasStaledReceipts = false,
    this.imageUrl,
  });

  factory CustomerAsset.fromJson(Map<String, dynamic> j) => CustomerAsset(
        assetId: j['asset_id'] as String? ?? '',
        publicId: j['public_id'] as String? ?? '',
        assetName: j['asset_name'] as String? ?? 'Unnamed asset',
        assetType: j['asset_type'] as String? ?? 'Unknown',
        trustTier: j['trust_tier'] as int?,
        eligible: j['eligible'] as bool? ?? false,
        currentDigest: j['current_digest'] as String?,
        lastVerifiedAt: j['last_verified_at'] != null
            ? DateTime.tryParse(j['last_verified_at'] as String)
            : null,
        hasStaledReceipts: j['has_staled_receipts'] as bool? ?? false,
        imageUrl: j['image_url'] as String?,
      );
}

class AssetCustodyEvent {
  final String eventId;
  final String eventType;
  final String eventDescription;
  final DateTime timestamp;
  final String by;

  const AssetCustodyEvent({
    required this.eventId,
    required this.eventType,
    required this.eventDescription,
    required this.timestamp,
    required this.by,
  });

  factory AssetCustodyEvent.fromJson(Map<String, dynamic> j) => AssetCustodyEvent(
        eventId: j['event_id'] as String? ?? '',
        eventType: j['event_type'] as String? ?? 'unknown',
        eventDescription: j['event_description'] as String? ?? '',
        timestamp: j['timestamp'] != null
            ? DateTime.tryParse(j['timestamp'] as String) ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        by: j['by'] as String? ?? '',
      );
}
