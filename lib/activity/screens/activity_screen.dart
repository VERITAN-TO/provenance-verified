// ActivityScreen — lists all customer submissions with status badges.
//
// Requires authentication (enforced by the router redirect).
// All status data comes from the backend — no fake data, no client claims.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/activity_models.dart';
import '../providers/activity_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(activityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACTIVITY', style: PvTypography.label),
      ),
      body: submissionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: PvColors.cyan, strokeWidth: 2),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(activityProvider),
        ),
        data: (items) => RefreshIndicator(
          color: PvColors.cyan,
          onRefresh: () async => ref.invalidate(activityProvider),
          child: items.isEmpty
              ? _EmptyState(
                  onSubmit: () => context.go('/submit'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _SubmissionRow(
                    item: items[i],
                    onTap: () => context.push(
                        '/activity/${items[i].submissionId}'),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/submit'),
        backgroundColor: PvColors.cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New Submission'),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Submission row
// ────────────────────────────────────────────────────────────────────────────

class _SubmissionRow extends StatelessWidget {
  final SubmissionStatusItem item;
  final VoidCallback onTap;

  const _SubmissionRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);

    return Semantics(
      label: '${item.assetName}, status: ${item.status.displayLabel}'
          '${item.hasEvidenceRequest ? ", evidence requested" : ""}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PvColors.surface,
            border: Border.all(
              // R28/R33: AUTHORITY_UNAVAILABLE → error border (R28-SD-04).
              color: item.determinationState == 'AUTHORITY_UNAVAILABLE'
                  ? PvColors.error
                  : item.hasEvidenceRequest
                      ? PvColors.warning
                      : PvColors.border,
              width: (item.determinationState == 'AUTHORITY_UNAVAILABLE' ||
                      item.hasEvidenceRequest)
                  ? 1.5
                  : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.assetName,
                            style: PvTypography.body.copyWith(
                              color: PvColors.onBackground,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.hasEvidenceRequest)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.assignment_late_outlined,
                              size: 14,
                              color: PvColors.warning,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(item.updatedAt),
                      style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                    ),
                    // R28/R33: branch on determination_state per flutter_consumer_contract.
                    // AUTHORITY_UNAVAILABLE: suppress tier, show badge + notice (R28-SD-04).
                    // DETERMINED: show tier (R28-SD-03). No credential badge — list credential_state
                    //   is PR47 placeholder; canonical authority is credential_lifecycle (detail).
                    //   Core PR48: lifecycle_sourced_from_pv_credentials_only=TRUE.
                    // NOT_DETERMINED / null: no lifecycle badge (R28 display_rules).
                    // MTA-1: SERVER DETERMINES TRUST.
                    if (item.determinationState == 'AUTHORITY_UNAVAILABLE') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PvColors.error.withAlpha(30),
                          border: Border.all(color: PvColors.error),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AUTHORITY UNAVAILABLE',
                          style: PvTypography.label.copyWith(
                              color: PvColors.error, fontSize: 9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Canonical determination temporarily unavailable. View details or refresh to retry.',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                      ),
                    ] else if (item.determinedTier != null &&
                        item.determinedTier!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      // Server-authored determination result — never client-claimed.
                      // credential_state from list endpoint is PR47 placeholder (NOT_ISSUED default).
                      // Canonical credential authority is credential_lifecycle from detail endpoint.
                      // Per Core PR48: lifecycle_sourced_from_pv_credentials_only=TRUE.
                      // List card shows no credential badge — R33/Core authority ruling.
                      Text(
                        'Determined: ${item.determinedTier}',
                        style: PvTypography.bodySmall.copyWith(
                            color: PvColors.onBackground,
                            fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        'Awaiting determination',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: item.status, color: statusColor),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, size: 18, color: PvColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Semantic color per status — uses the canonical PvColors palette.
  static Color _statusColor(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.issued:                  return PvColors.success;
      case SubmissionStatus.moreInformationRequired:
      case SubmissionStatus.additionalInfoRequested:  return PvColors.warning;
      case SubmissionStatus.closed:                   return PvColors.muted;
      case SubmissionStatus.submitted:
      case SubmissionStatus.paymentConfirmed:        return PvColors.silver;
      case SubmissionStatus.awaitingShipment:
      case SubmissionStatus.inTransit:
      case SubmissionStatus.returnInTransit:         return PvColors.cyan;
      case SubmissionStatus.received:
      case SubmissionStatus.intakeComplete:
      case SubmissionStatus.evidenceReview:
      case SubmissionStatus.determination:
      case SubmissionStatus.issuancePending:         return PvColors.cyan;
      case SubmissionStatus.unknown:                 return PvColors.muted;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inDays > 0) return 'Updated ${diff.inDays}d ago';
    if (diff.inHours > 0) return 'Updated ${diff.inHours}h ago';
    if (diff.inMinutes > 0) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated just now';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status badge
// ────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final SubmissionStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
// Empty state
// ────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyState({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: PvColors.muted),
            const SizedBox(height: 16),
            const Text(
              'No submissions yet',
              style: PvTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a gemstone for PROVENANCE VERIFIED™ evaluation to start tracking it here.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.add),
              label: const Text('Submit a Gemstone'),
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.cyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
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
            const Text('Could not load submissions', style: PvTypography.title),
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
