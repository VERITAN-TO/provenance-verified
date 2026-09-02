// Home screen — works for anonymous users (quick actions + recent scans)
// and authenticated customers (full dashboard with alerts + submissions).
// Trust display follows MTA1 rules: server determines trust, mobile displays it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final session = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROVENANCE VERIFIED™', style: PvTypography.label),
        actions: [
          if (isAuthenticated)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'My PV',
              onPressed: () => context.push('/my-pv'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: PvColors.cyan,
        onRefresh: () async {
          ref.invalidate(recentScansProvider);
          if (isAuthenticated) {
            ref.invalidate(homeAlertsProvider);
            ref.invalidate(homeSubmissionsProvider);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isAuthenticated && session != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Welcome, ${session.displayName}',
                  style: PvTypography.title,
                ),
              ),

            // ── Quick actions ──────────────────────────────────────────────
            const _SectionHeader('QUICK ACTIONS'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/scan'),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan PV Code'),
                    style: FilledButton.styleFrom(
                      backgroundColor: PvColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/manual'),
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text('Look Up ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PvColors.onBackground,
                      side: const BorderSide(color: PvColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Alerts (authenticated only) ────────────────────────────────
            if (isAuthenticated) ...[
              const _SectionHeader('ALERTS'),
              const SizedBox(height: 8),
              _AlertsRow(),
              const SizedBox(height: 24),

              // ── Active submissions ──────────────────────────────────────
              const _SectionHeader('ACTIVE SUBMISSIONS'),
              const SizedBox(height: 8),
              _SubmissionsList(),
              const SizedBox(height: 24),
            ],

            // ── Recent scans ───────────────────────────────────────────────
            const _SectionHeader('RECENT SCANS'),
            const SizedBox(height: 8),
            _RecentScansList(),
            const SizedBox(height: 24),

            // ── Authenticated quick links ──────────────────────────────────
            if (isAuthenticated) ...[
              const _SectionHeader('MY PROVENANCE'),
              const SizedBox(height: 8),
              _AuthenticatedLinks(),
              const SizedBox(height: 24),
            ],

            // ── Sign-in CTA for anonymous users ───────────────────────────
            if (!isAuthenticated)
              _SignInCallout(),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Alerts row (horizontal scroll)
// ────────────────────────────────────────────────────────────────────────────

class _AlertsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(homeAlertsProvider);
    return alertsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const _EmptyState('Could not load alerts'),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const _EmptyState('No active alerts');
        }
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _AlertCard(alert: alerts[i]),
          ),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final TrustAlert alert;
  const _AlertCard({required this.alert});

  Color _alertColor() {
    switch (alert.alertType) {
      case AlertType.trustStateChange: return PvColors.error;
      case AlertType.staleReceipt: return PvColors.warning;
      case AlertType.certificationExpiring: return PvColors.warning;
      case AlertType.submissionRequiresAction: return PvColors.cyan;
      case AlertType.unknown: return PvColors.muted;
    }
  }

  IconData _alertIcon() {
    switch (alert.alertType) {
      case AlertType.trustStateChange: return Icons.swap_vert_circle_outlined;
      case AlertType.staleReceipt: return Icons.update_outlined;
      case AlertType.certificationExpiring: return Icons.timer_outlined;
      case AlertType.submissionRequiresAction: return Icons.assignment_late_outlined;
      case AlertType.unknown: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _alertColor();
    return Semantics(
      label: 'Alert: ${alert.message}',
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PvColors.surface,
          border: Border.all(color: alert.read ? PvColors.border : color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_alertIcon(), color: color, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alert.assetName,
                    style: PvTypography.label.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!alert.read)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                alert.message,
                style: PvTypography.bodySmall.copyWith(color: PvColors.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Active submissions list
// ────────────────────────────────────────────────────────────────────────────

class _SubmissionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(homeSubmissionsProvider);
    return submissionsAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const _EmptyState('Could not load submissions'),
      data: (submissions) {
        if (submissions.isEmpty) {
          return const _EmptyState('No active submissions');
        }
        return Column(
          children: submissions
              .map((s) => _SubmissionTile(submission: s))
              .toList(),
        );
      },
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final SubmissionSummary submission;
  const _SubmissionTile({required this.submission});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return PvColors.warning;
      case 'approved': return PvColors.success;
      case 'rejected': return PvColors.error;
      case 'in_review': return PvColors.cyan;
      default: return PvColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(submission.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: PvColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PvColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(submission.assetName, style: PvTypography.body),
        subtitle: Text(
          'Updated ${_relativeTime(submission.updatedAt)}',
          style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            submission.status.toUpperCase().replaceAll('_', ' '),
            style: PvTypography.label.copyWith(color: color, fontSize: 9),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Recent scans list
// ────────────────────────────────────────────────────────────────────────────

class _RecentScansList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(recentScansProvider);
    return scansAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const _EmptyState('Could not load recent scans'),
      data: (scans) {
        if (scans.isEmpty) {
          return const _EmptyState('No recent scans — tap Scan PV Code to start');
        }
        return Column(
          children: scans.map((s) => _RecentScanTile(scan: s)).toList(),
        );
      },
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final RecentScan scan;
  const _RecentScanTile({required this.scan});

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
    if (tier == null) return 'NOT QUALIFIED';
    switch (tier) {
      case 1: return 'T1';
      case 2: return 'T2';
      case 3: return 'T3';
      case 4: return 'T4';
      default: return 'T$tier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(scan.trustTier);
    final label = _tierLabel(scan.trustTier);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: PvColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PvColors.border),
      ),
      child: ListTile(
        dense: true,
        onTap: () => context.push('/verify/${scan.publicId}'),
        title: Text(scan.publicId, style: PvTypography.mono.copyWith(color: PvColors.onBackground)),
        subtitle: Text(
          _relativeTime(scan.scannedAt),
          style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: PvTypography.label.copyWith(color: color, fontSize: 9)),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Authenticated quick links
// ────────────────────────────────────────────────────────────────────────────

class _AuthenticatedLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickLinkChip(
          icon: Icons.inventory_2_outlined,
          label: 'My PV',
          onTap: () => context.push('/my-pv'),
        ),
        _QuickLinkChip(
          icon: Icons.add_circle_outline,
          label: 'Submit Asset',
          onTap: () => context.push('/submit'),
        ),
        _QuickLinkChip(
          icon: Icons.receipt_long_outlined,
          label: 'Receipts',
          onTap: () => context.push('/receipts'),
        ),
      ],
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLinkChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: PvColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: PvColors.silver),
            const SizedBox(width: 6),
            Text(label, style: PvTypography.bodySmall.copyWith(color: PvColors.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sign-in callout for anonymous users
// ────────────────────────────────────────────────────────────────────────────

class _SignInCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PvColors.surface,
        border: Border.all(color: PvColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: PvColors.silver, size: 32),
          const SizedBox(height: 12),
          const Text('Sign in for your full dashboard', style: PvTypography.title),
          const SizedBox(height: 6),
          Text(
            'Track your submissions, manage assets, and receive trust alerts.',
            style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/sign-in'),
            style: FilledButton.styleFrom(
              backgroundColor: PvColors.cyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
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
  Widget build(BuildContext context) => Text(
        text,
        style: PvTypography.label.copyWith(color: PvColors.muted),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
        ),
      );
}
