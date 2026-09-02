// Asset detail — full view of a customer's provenance asset.
// MTA1 CTO constraint: never visually overclaim evidence.
// "Laboratory confirmed" or similar labels require explicit evidence scope.
// Trust display follows the same conservative pattern as trust_result_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/my_pv_models.dart';
import '../providers/my_pv_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class AssetDetailScreen extends ConsumerWidget {
  final String assetId;
  const AssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assetDetailProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {
              // Share the public ID — no private data surfaced via share.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading asset detail'),
        ),
        error: (err, _) => _ErrorView(error: err, assetId: assetId, ref: ref),
        data: (detail) => _DetailView(detail: detail, assetId: assetId, ref: ref),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Full detail view
// ────────────────────────────────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  final Map<String, dynamic> detail;
  final String assetId;
  final WidgetRef ref;
  const _DetailView({required this.detail, required this.assetId, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Parse top-level asset fields
    final asset = CustomerAsset.fromJson(detail);

    // Parse custody events
    final custodyRaw = detail['custody_history'] as List? ?? [];
    final custodyEvents = custodyRaw
        .whereType<Map<String, dynamic>>()
        .map(AssetCustodyEvent.fromJson)
        .toList();

    // Parse evidence scope (raw list of maps — displayed conservatively)
    final evidenceRaw = detail['evidence'] as List? ?? [];

    // Parse limitations (raw list of maps)
    final limitationsRaw = detail['limitations'] as List? ?? [];

    // Parse reliance receipts for this asset
    final receiptsRaw = detail['reliance_receipts'] as List? ?? [];

    // Stale state
    final hasStaledReceipts = asset.hasStaledReceipts;

    return RefreshIndicator(
      color: PvColors.cyan,
      onRefresh: () async => ref.invalidate(assetDetailProvider(assetId)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stale banner ──────────────────────────────────────────────────
          if (hasStaledReceipts) _StaledReceiptsBanner(),

          // ── Trust tier badge ──────────────────────────────────────────────
          _TierBadge(asset: asset),
          const SizedBox(height: 16),

          // ── Basic info ───────────────────────────────────────────────────
          _InfoRow('Name', asset.assetName),
          _InfoRow('Type', asset.assetType),
          _InfoRow('PV ID', asset.publicId),
          if (asset.lastVerifiedAt != null)
            _InfoRow('Last Verified', _formatDate(asset.lastVerifiedAt!)),
          if (asset.currentDigest != null && asset.currentDigest!.isNotEmpty)
            _InfoRow('Digest', asset.currentDigest!),

          const Divider(height: 32),

          // ── Evidence scope ────────────────────────────────────────────────
          // Conservative: only list what the server provided, no inferred labels.
          _SectionHeader('EVIDENCE SCOPE'),
          const SizedBox(height: 4),
          const Text(
            'Evidence items listed as provided by the verification authority. '
            'No inferences beyond what is explicitly stated.',
            style: TextStyle(color: PvColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _EvidenceScopeList(evidenceRaw: evidenceRaw),

          const Divider(height: 32),

          // ── Limitations ───────────────────────────────────────────────────
          if (limitationsRaw.isNotEmpty) ...[
            _LimitationsList(limitationsRaw: limitationsRaw),
            const Divider(height: 32),
          ],

          // ── Custody history ───────────────────────────────────────────────
          _SectionHeader('CUSTODY HISTORY'),
          const SizedBox(height: 8),
          _CustodyTimeline(events: custodyEvents),

          const Divider(height: 32),

          // ── Reliance receipts ─────────────────────────────────────────────
          _SectionHeader('RELIANCE RECEIPTS'),
          const SizedBox(height: 8),
          _AssetReceiptsList(receiptsRaw: receiptsRaw),

          const Divider(height: 32),

          // ── Action buttons ────────────────────────────────────────────────
          _ActionButtons(asset: asset),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Stale banner
// ────────────────────────────────────────────────────────────────────────────

class _StaledReceiptsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Warning: one or more reliance receipts are stale for this asset',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: PvColors.warning.withAlpha(30),
          border: Border.all(color: PvColors.warning),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.update, color: PvColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'STALE RECEIPTS — One or more reliance receipts for this asset are stale and should be requerierd.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Trust tier badge — conservative (matches TrustBadge pattern)
// ────────────────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final CustomerAsset asset;
  const _TierBadge({required this.asset});

  Color _tierColor(int? tier) {
    switch (tier) {
      case 1: return PvColors.tier1;
      case 2: return PvColors.tier2;
      case 3: return PvColors.tier3;
      case 4: return PvColors.tier4;
      default: return PvColors.muted;
    }
  }

  String _tierLabel(int? tier) {
    // Never expose a qualified tier label for an ineligible or unqualified asset.
    if (!asset.eligible) return 'NOT QUALIFIED';
    if (tier == null) return 'NOT QUALIFIED';
    switch (tier) {
      case 1: return 'T1 ASSET FINGERPRINT';
      case 2: return 'T2 DECLARED PROVENANCE';
      case 3: return 'T3 EVIDENCE-VERIFIED';
      case 4: return 'T4 GOLD STANDARD';
      default: return 'TIER $tier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(asset.eligible ? asset.trustTier : null);
    final label = _tierLabel(asset.trustTier);
    return Semantics(
      label: 'Trust tier: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: PvTypography.label.copyWith(color: color, letterSpacing: 1.2),
              semanticsLabel: label,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Evidence scope — displays raw server data, no inferred labels
// ────────────────────────────────────────────────────────────────────────────

class _EvidenceScopeList extends StatelessWidget {
  final List evidenceRaw;
  const _EvidenceScopeList({required this.evidenceRaw});

  @override
  Widget build(BuildContext context) {
    if (evidenceRaw.isEmpty) {
      return const Text(
        'No evidence scope recorded',
        style: TextStyle(color: PvColors.muted),
      );
    }
    return Column(
      children: evidenceRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => _EvidenceItem(item: e))
          .toList(),
    );
  }
}

class _EvidenceItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _EvidenceItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? 'Unknown type';
    final source = item['source'] as String? ?? '';
    final integrityState = item['integrity_verification_state'] as String? ?? '';
    final isRelatedParty = item['related_party'] == true ||
        item['related_party']?.toString() == 'true';
    final isIntegrityVerified = integrityState == 'VERIFIED';

    return Semantics(
      label: '$type${isRelatedParty ? ", related party" : ""}',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(type, style: PvTypography.body)),
                  if (isRelatedParty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: PvColors.warning.withAlpha(40),
                        border: Border.all(color: PvColors.warning),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RELATED PARTY',
                        style: PvTypography.label.copyWith(color: PvColors.warning),
                        semanticsLabel: 'Related party evidence',
                      ),
                    ),
                ],
              ),
              if (source.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Issuer: $source', style: PvTypography.bodySmall),
                ),
              if (isIntegrityVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 14, color: PvColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Integrity verified',
                        style: PvTypography.bodySmall
                            .copyWith(color: PvColors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Limitations
// ────────────────────────────────────────────────────────────────────────────

class _LimitationsList extends StatelessWidget {
  final List limitationsRaw;
  const _LimitationsList({required this.limitationsRaw});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIMITATIONS',
            style: PvTypography.label.copyWith(color: PvColors.limitation)),
        const SizedBox(height: 8),
        ...limitationsRaw
            .whereType<Map<String, dynamic>>()
            .map((l) => _LimitationItem(item: l)),
      ],
    );
  }
}

class _LimitationItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LimitationItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final code = item['code'] as String? ?? '';
    final message = item['message'] as String? ?? '';
    return Semantics(
      label: 'Limitation: $code',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: PvColors.limitation, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code.isNotEmpty)
                    Text(code,
                        style: PvTypography.label
                            .copyWith(color: PvColors.limitation)),
                  if (message.isNotEmpty)
                    Text(message, style: PvTypography.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Custody timeline
// ────────────────────────────────────────────────────────────────────────────

class _CustodyTimeline extends StatelessWidget {
  final List<AssetCustodyEvent> events;
  const _CustodyTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text(
        'No custody history recorded',
        style: TextStyle(color: PvColors.muted),
      );
    }
    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4, right: 12),
                    decoration: BoxDecoration(
                      color: PvColors.cyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.only(left: 4, right: 21),
                        color: PvColors.border,
                      ),
                    ),
                ],
              ),
              // Event content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.eventType.replaceAll('_', ' '),
                        style: PvTypography.label.copyWith(
                            color: PvColors.onBackground, letterSpacing: 0.4),
                      ),
                      if (e.eventDescription.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(e.eventDescription,
                              style: PvTypography.bodySmall),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${_formatDate(e.timestamp)}${e.by.isNotEmpty ? ' · ${e.by}' : ''}',
                          style: PvTypography.bodySmall
                              .copyWith(color: PvColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Asset-specific reliance receipts
// ────────────────────────────────────────────────────────────────────────────

class _AssetReceiptsList extends StatelessWidget {
  final List receiptsRaw;
  const _AssetReceiptsList({required this.receiptsRaw});

  @override
  Widget build(BuildContext context) {
    if (receiptsRaw.isEmpty) {
      return const Text(
        'No reliance receipts for this asset',
        style: TextStyle(color: PvColors.muted),
      );
    }
    return Column(
      children: receiptsRaw
          .whereType<Map<String, dynamic>>()
          .map((r) => _ReceiptRow(receipt: r))
          .toList(),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const _ReceiptRow({required this.receipt});

  Color _validityColor(String? state) {
    switch (state?.toUpperCase()) {
      case 'VALID': return PvColors.success;
      case 'INVALIDATED': return PvColors.error;
      case 'EXPIRED': return PvColors.warning;
      default: return PvColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptId = receipt['receipt_id'] as String? ?? '';
    final validity = receipt['validity_state'] as String? ?? 'unknown';
    final color = _validityColor(validity);
    final purpose = receipt['purpose'] as String? ?? '';
    final createdAt = receipt['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: PvColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PvColors.border),
      ),
      child: ListTile(
        dense: true,
        onTap: receiptId.isNotEmpty
            ? () => context.push('/receipts/$receiptId')
            : null,
        title: Text(
          purpose.isNotEmpty ? purpose : 'Receipt',
          style: PvTypography.body,
        ),
        subtitle: createdAt.isNotEmpty
            ? Text(
                _formatDate(createdAt),
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            validity.toUpperCase(),
            style: PvTypography.label.copyWith(color: color, fontSize: 9),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Action buttons
// ────────────────────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final CustomerAsset asset;
  const _ActionButtons({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/verify/${asset.publicId}'),
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: const Text('Verify Now'),
          style: FilledButton.styleFrom(
            backgroundColor: PvColors.cyan,
            foregroundColor: Colors.black,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/submit'),
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: const Text('Submit Update'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PvColors.onBackground,
            side: const BorderSide(color: PvColors.border),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share coming soon')),
            );
          },
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Share'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PvColors.onBackground,
            side: const BorderSide(color: PvColors.border),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: PvTypography.label.copyWith(color: PvColors.muted)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
            ),
            Expanded(
              child: Text(value, style: PvTypography.body),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final String assetId;
  final WidgetRef ref;
  const _ErrorView(
      {required this.error, required this.assetId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final msg = error.toString();
    final isNotFound = msg.contains('not_found');
    final isAuth = msg.contains('not_authenticated');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuth ? Icons.lock_outline : Icons.error_outline,
              color: isAuth ? PvColors.silver : PvColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isNotFound
                  ? 'Asset not found'
                  : isAuth
                      ? 'Session expired'
                      : 'Could not load asset',
              style: PvTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              isAuth
                  ? 'Please sign in again.'
                  : 'Pull down to retry.',
              style:
                  PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
            ),
            if (isAuth) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/sign-in'),
                style: FilledButton.styleFrom(
                  backgroundColor: PvColors.cyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Sign In'),
              ),
            ] else ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(assetDetailProvider(assetId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
