import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trust_provider.dart';
import '../trust_models.dart';
import '../widgets/trust_badge.dart';
import '../widgets/claims_list.dart';
import '../widgets/evidence_list.dart';
import '../widgets/limitations_widget.dart';
import '../widgets/prohibited_inferences_widget.dart';
import '../widgets/continuity_widget.dart';
import '../widgets/stale_banner.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class TrustResultScreen extends ConsumerWidget {
  final String publicId;
  const TrustResultScreen({super.key, required this.publicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));

    return Scaffold(
      appBar: AppBar(
        title: Text(publicId, style: PvTypography.mono),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Reliance receipts',
            onPressed: () => context.push('/receipts'),
          ),
        ],
      ),
      body: trustAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading trust record',
          ),
        ),
        error: (err, _) => _ErrorView(error: err, publicId: publicId),
        data: (record) => _RecordView(record: record, ref: ref),
      ),
    );
  }
}

class _RecordView extends StatelessWidget {
  final TrustRecord record;
  final WidgetRef ref;
  const _RecordView({required this.record, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StaleBanner(
          freshness: record.freshness?.state ?? FreshnessState.unknown,
          onRequery: () => ref.invalidate(trustRecordProvider(record.publicId)),
        ),
        TrustBadge(record: record),
        const SizedBox(height: 16),
        _InfoRow('Record', record.publicId),
        _InfoRow('Subject', record.subject.physicalSubjectId.isNotEmpty ? record.subject.physicalSubjectId : record.subject.subjectId),
        if (record.subject.identityState != IdentityState.unknown)
          _InfoRow('Identity', record.subject.identityState.name.toUpperCase()),
        const Divider(height: 32),
        _SectionHeader('CLAIMS'),
        ClaimsList(claims: record.claimVerdicts),
        const Divider(height: 32),
        _SectionHeader('EVIDENCE'),
        EvidenceList(evidence: record.evidence),
        const Divider(height: 32),
        ContinuityWidget(record: record),
        const SizedBox(height: 16),
        LimitationsWidget(limitations: record.limitations),
        const SizedBox(height: 16),
        ProhibitedInferencesWidget(prohibited: record.prohibitedInferences),
        const Divider(height: 32),
        _ActionButtons(record: record),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final TrustRecord record;
  const _ActionButtons({required this.record});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.push('/verify/${record.publicId}/why-this-tier'),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Why this tier?'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/verify/${record.publicId}/why-not-higher'),
          icon: const Icon(Icons.arrow_upward, size: 18),
          label: const Text('Why not higher?'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/verify/${record.publicId}/authority'),
          icon: const Icon(Icons.account_balance_outlined, size: 18),
          label: const Text('Authority'),
        ),
        if (record.isQualified)
          FilledButton.icon(
            onPressed: () => context.push('/verify/${record.publicId}/actionability'),
            icon: const Icon(Icons.gavel, size: 18),
            label: const Text('Assess Reliance'),
            style: FilledButton.styleFrom(backgroundColor: PvColors.tier3),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
          ),
          Expanded(child: Text(value, style: PvTypography.body)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: PvTypography.label.copyWith(color: PvColors.muted)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final String publicId;
  const _ErrorView({required this.error, required this.publicId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: PvColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Unable to load $publicId', style: PvTypography.title),
            const SizedBox(height: 8),
            Text(error.toString(), style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
          ],
        ),
      ),
    );
  }
}
