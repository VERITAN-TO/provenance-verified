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
          onPressed: () => Navigator.of(context).pop(),
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
              if (detail.status == SubmissionStatus.moreInformationRequired &&
                  detail.evidenceRequestInstructions != null) ...[
                _EvidenceRequestSection(
                  instructions: detail.evidenceRequestInstructions!,
                ),
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
          _DetailRow('Requested Service', detail.requestedServiceTier),
          const SizedBox(height: 6),
          _DetailRow('Last Updated', _formatDate(detail.updatedAt)),
        ],
      ),
    );
  }

  static Color _statusColor(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.issued:                  return PvColors.success;
      case SubmissionStatus.moreInformationRequired: return PvColors.warning;
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
    return IntrinsicHeight(
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
