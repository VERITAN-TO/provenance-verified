// SubmissionDetailScreen — full status timeline for a single submission.
//
// All data is server-authoritative.
// The client displays what the backend reports; it makes no trust claims.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/activity_models.dart';
import '../providers/activity_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

// Statuses where server determination is complete (or in progress and
// worth showing the re-query button).
const _determinationStatuses = {
  SubmissionStatus.determination,
  SubmissionStatus.issuancePending,
  SubmissionStatus.issued,
};

class SubmissionDetailScreen extends ConsumerWidget {
  final String submissionId;

  const SubmissionDetailScreen({
    super.key,
    required this.submissionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(submissionDetailProvider(submissionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SUBMISSION DETAIL', style: PvTypography.label),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: PvColors.cyan, strokeWidth: 2),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(submissionDetailProvider(submissionId)),
        ),
        data: (detail) => RefreshIndicator(
          color: PvColors.cyan,
          onRefresh: () async =>
              ref.invalidate(submissionDetailProvider(submissionId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header card ─────────────────────────────────────────────
              _HeaderCard(detail: detail),
              const SizedBox(height: 16),

              // ── Evidence request section ─────────────────────────────────
              if ((detail.status == SubmissionStatus.moreInformationRequired ||
                      detail.status == SubmissionStatus.additionalInfoRequested) &&
                  detail.evidenceRequestInstructions != null) ...[
                _EvidenceRequestSection(
                  instructions: detail.evidenceRequestInstructions!,
                ),
                const SizedBox(height: 16),
              ],

              // ── Determination result ─────────────────────────────────────
              if (detail.determination != null) ...[
                _DeterminationSection(
                  det: detail.determination!,
                  submissionId: detail.submissionId,
                  ref: ref,
                ),
                const SizedBox(height: 16),
              ] else if (_determinationStatuses.contains(detail.status)) ...[
                _RequerySection(
                  submissionId: detail.submissionId,
                  ref: ref,
                ),
                const SizedBox(height: 16),
              ],

              // ── Settlement CTA — R29: hasSettlementSeam + null data + determination ─
              // PR #47 data.settlement is the explicit server seam. Key present but
              // null means no order linked yet. MONEY_CONTROLS_TRUST = FALSE.
              if (detail.hasSettlementSeam &&
                  detail.settlementData == null &&
                  detail.determination != null) ...[
                _SettlementCtaSection(submissionId: detail.submissionId),
                const SizedBox(height: 16),
              ],

              // ── Settlement status — FREE or PAID ─────────────────────────
              if (detail.settlementPaymentStatus != null &&
                  detail.settlementPaymentStatus !=
                      SettlementPaymentStatus.unknown) ...[
                _SettlementStatusSection(
                  status: detail.settlementPaymentStatus!,
                ),
                const SizedBox(height: 16),
              ],

              // ── Post-settlement My PV navigation ─────────────────────────
              if (detail.settlementPaymentStatus == SettlementPaymentStatus.free ||
                  detail.settlementPaymentStatus == SettlementPaymentStatus.paid) ...[
                _MyPvNavigationSection(),
                const SizedBox(height: 16),
              ],

              // ── Issued: view in My PV ────────────────────────────────────
              if (detail.status == SubmissionStatus.issued) ...[
                _IssuedAction(
                  assetId: detail.issuedAssetId,
                  onViewAsset: detail.issuedAssetId != null
                      ? () {
                          context.go(
                              '/my-pv/asset/${detail.issuedAssetId}');
                        }
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // ── Public provenance record — R29: settlement authority seam wired ──
              // PR #47 data.settlement.isSettled (FREE or PAID) is the authority gate.
              // MTA-1: SERVER DETERMINES TRUST. MONEY_CONTROLS_TRUST = FALSE.
              if (detail.settlementData != null &&
                  detail.settlementData!.isSettled &&
                  detail.publicId != null) ...[
                _ProvenanceRecordAction(
                  publicId: detail.publicId!,
                  determinedAt: detail.determinedAt,
                ),
                const SizedBox(height: 16),
              ],

              // ── Status timeline ──────────────────────────────────────────
              _SectionHeader('STATUS TIMELINE'),
              const SizedBox(height: 8),
              _StatusTimeline(events: detail.custodyEvents),
              const SizedBox(height: 24),

              // ── Support link ─────────────────────────────────────────────
              _SupportLink(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Header card
// ────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final SubmissionDetail detail;
  const _HeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(detail.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PvColors.surface,
        border: Border.all(color: PvColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.assetName,
                  style: PvTypography.title.copyWith(color: PvColors.onBackground),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(status: detail.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: PvColors.border, height: 1),
          const SizedBox(height: 12),
          _DetailRow('Submission ID', detail.submissionId, mono: true),
          const SizedBox(height: 6),
          _DetailRow('Last Updated', _formatDate(detail.updatedAt)),
        ],
      ),
    );
  }

  static Color _statusColor(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.issued:                  return PvColors.success;
      case SubmissionStatus.moreInformationRequired:
      case SubmissionStatus.additionalInfoRequested: return PvColors.warning;
      case SubmissionStatus.closed:                  return PvColors.muted;
      case SubmissionStatus.inTransit:
      case SubmissionStatus.returnInTransit:         return PvColors.cyan;
      default:                                       return PvColors.silver;
    }
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetailRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: mono
                ? PvTypography.mono.copyWith(color: PvColors.cyan, fontSize: 12)
                : PvTypography.body.copyWith(color: PvColors.onBackground),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SubmissionStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayLabel.toUpperCase(),
        style: PvTypography.label.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Determination section — shown when server has returned a determination.
// CUSTOMER_SELECTS_TIER = FALSE: tier is always displayed as determined by
// the server, never asserted by the client.
// ────────────────────────────────────────────────────────────────────────────

class _DeterminationSection extends StatelessWidget {
  final DeterminationResult det;
  final String submissionId;
  final WidgetRef ref;
  const _DeterminationSection(
      {required this.det, required this.submissionId, required this.ref});

  Color _tierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'T1': return PvColors.tier1;
      case 'T2': return PvColors.tier2;
      case 'T3': return PvColors.tier3;
      case 'T4': return PvColors.tier4;
      default:   return PvColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(det.tier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tierColor.withAlpha(15),
        border: Border.all(color: tierColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'DETERMINATION RESULT',
                style: PvTypography.label.copyWith(color: tierColor),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(submissionDetailProvider(submissionId)),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Re-query', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tierColor,
                  side: BorderSide(color: tierColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tier badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tierColor.withAlpha(30),
              border: Border.all(color: tierColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Tier: ${det.tier}',
              style: PvTypography.label.copyWith(
                  color: tierColor, letterSpacing: 1.2),
            ),
          ),
          if (det.whyThisTier != null &&
              det.whyThisTier!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('WHY THIS TIER',
                style: PvTypography.label.copyWith(color: PvColors.muted)),
            const SizedBox(height: 4),
            Text(det.whyThisTier!, style: PvTypography.body),
          ],
          if (det.whyNotNextTier != null &&
              det.whyNotNextTier!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('WHY NOT HIGHER',
                style: PvTypography.label.copyWith(color: PvColors.muted)),
            const SizedBox(height: 4),
            Text(det.whyNotNextTier!, style: PvTypography.body),
          ],
          if (det.limitations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('LIMITATIONS',
                style:
                    PvTypography.label.copyWith(color: PvColors.limitation)),
            const SizedBox(height: 4),
            ...det.limitations.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: PvColors.limitation),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(l,
                            style: PvTypography.bodySmall.copyWith(
                                color: PvColors.onSurface))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Re-query section — shown when determination is in progress but no result
// has been returned yet (e.g. status == DETERMINATION).
// ────────────────────────────────────────────────────────────────────────────

class _RequerySection extends StatelessWidget {
  final String submissionId;
  final WidgetRef ref;
  const _RequerySection({required this.submissionId, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PvColors.surface,
        border: Border.all(color: PvColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: PvColors.cyan, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Determination in progress. Tap Re-query to check for results.',
              style: PvTypography.body,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () =>
                ref.invalidate(submissionDetailProvider(submissionId)),
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Re-query', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: PvColors.cyan,
              side: const BorderSide(color: PvColors.cyan),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Evidence request section
// ────────────────────────────────────────────────────────────────────────────

class _EvidenceRequestSection extends StatelessWidget {
  final String instructions;
  const _EvidenceRequestSection({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PvColors.warning.withAlpha(15),
        border: Border.all(color: PvColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_outlined,
                  color: PvColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'MORE INFORMATION REQUIRED',
                style: PvTypography.label.copyWith(color: PvColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            instructions,
            style: PvTypography.body.copyWith(color: PvColors.onSurface),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              // Navigating to the submit screen allows the customer to supply
              // additional evidence.  A future version may deep-link into a
              // specific "additional evidence" sub-flow.
              context.go('/submit');
            },
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: const Text('Submit Additional Evidence'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PvColors.warning,
              side: const BorderSide(color: PvColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Settlement CTA — determination is complete but settlement has not occurred.
// MONEY_CONTROLS_TRUST = FALSE: this CTA opens the settlement flow only;
// settlement does not change the trust determination.
// ────────────────────────────────────────────────────────────────────────────

class _SettlementCtaSection extends StatelessWidget {
  final String submissionId;
  const _SettlementCtaSection({required this.submissionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PvColors.cyan.withAlpha(15),
        border: Border.all(color: PvColors.cyan),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: PvColors.cyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'AWAITING SETTLEMENT',
                style: PvTypography.label.copyWith(color: PvColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Determination is complete. Settlement finalises the record. '
            'The determined tier does not change at settlement.',
            style: PvTypography.body,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/submit'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Complete Settlement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PvColors.cyan,
                side: const BorderSide(color: PvColors.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Settlement status — shows FREE or PAID settlement state.
// Informational only; MONEY_CONTROLS_TRUST = FALSE.
// ────────────────────────────────────────────────────────────────────────────

class _SettlementStatusSection extends StatelessWidget {
  final SettlementPaymentStatus status;
  const _SettlementStatusSection({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == SettlementPaymentStatus.free ||
            status == SettlementPaymentStatus.paid
        ? PvColors.success
        : PvColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            status.displayLabel.toUpperCase(),
            style: PvTypography.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Post-settlement My PV navigation — shown after FREE or PAID settlement.
// ────────────────────────────────────────────────────────────────────────────

class _MyPvNavigationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.go('/my-pv'),
        icon: const Icon(Icons.verified_user_outlined, size: 16),
        label: const Text('View in My PV'),
        style: OutlinedButton.styleFrom(
          foregroundColor: PvColors.onBackground,
          side: const BorderSide(color: PvColors.border),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Issued action
// ────────────────────────────────────────────────────────────────────────────

class _IssuedAction extends StatelessWidget {
  final String? assetId;
  final VoidCallback? onViewAsset;
  const _IssuedAction({this.assetId, this.onViewAsset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PvColors.success.withAlpha(15),
        border: Border.all(color: PvColors.success),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: PvColors.success, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This submission has been issued a PROVENANCE VERIFIED™ record.',
              style: PvTypography.body,
            ),
          ),
          if (onViewAsset != null) ...[
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onViewAsset,
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.success,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('View Asset', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status timeline
// ────────────────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final List<CustodyEvent> events;
  const _StatusTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'No custody events recorded yet.',
        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
      );
    }

    return Column(
      children: events.asMap().entries.map((entry) {
        final i     = entry.key;
        final event = entry.value;
        final isLast = i == events.length - 1;
        return _TimelineItem(event: event, isLast: isLast);
      }).toList(),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final CustodyEvent event;
  final bool isLast;
  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${event.eventType.replaceAll('_', ' ')}: ${event.description}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Timeline connector ────────────────────────────────────────
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: PvColors.cyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        color: PvColors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Event content ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventType
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      style: PvTypography.label.copyWith(color: PvColors.silver),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      style: PvTypography.body.copyWith(color: PvColors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(event.timestamp),
                      style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

// ────────────────────────────────────────────────────────────────────────────
// Support link
// ────────────────────────────────────────────────────────────────────────────

class _SupportLink extends StatelessWidget {
  static const _supportUrl = 'https://provenanceverified.com/support';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          final uri = Uri.parse(_supportUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.help_outline, size: 18, color: PvColors.silver),
        label: Text(
          'Contact Support',
          style: PvTypography.body.copyWith(color: PvColors.silver),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Section header
// ────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PvTypography.label.copyWith(color: PvColors.muted),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Provenance record link — wired in R29 via settlement authority seam.
// Gate: settlement.isSettled (FREE or PAID from PR #47 data.settlement).
// MTA-1: SERVER DETERMINES TRUST.
// LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY.
// ────────────────────────────────────────────────────────────────────────────

class _ProvenanceRecordAction extends StatelessWidget {
  final String publicId;
  final DateTime? determinedAt;
  const _ProvenanceRecordAction({required this.publicId, this.determinedAt});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'View public provenance record for $publicId',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PvColors.surface,
          border: Border.all(color: PvColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROVENANCE RECORD AVAILABLE',
              style: PvTypography.label.copyWith(color: PvColors.muted),
            ),
            const SizedBox(height: 6),
            SelectableText(publicId, style: PvTypography.mono),
            if (determinedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Determined ${_formatDate(determinedAt!)}',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/verify/$publicId'),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Verify Provenance Record'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PvColors.onBackground,
                  side: const BorderSide(color: PvColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error state
// ────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: PvColors.error),
            const SizedBox(height: 16),
            const Text('Could not load submission', style: PvTypography.title),
            const SizedBox(height: 8),
            Text(
              message,
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PvColors.onBackground,
                side: const BorderSide(color: PvColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
