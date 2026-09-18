import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../trust/providers/trust_provider.dart';
import '../../trust/trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

// PROFESSIONAL_CANNOT_SELECT_TIER — professional mode projects canonical trust only.
// Server determines tier. This screen may not select tier, strengthen evidence,
// issue marks, or bypass tenant/auth. Batch fails closed on partial/unknown authority.
// MONEY_CONTROLS_TRUST = FALSE. PHYSICAL_MATCH_NOT_SUPPORTED.

class ProfessionalBatchScreen extends ConsumerStatefulWidget {
  const ProfessionalBatchScreen({super.key});

  @override
  ConsumerState<ProfessionalBatchScreen> createState() => _ProfessionalBatchScreenState();
}

class _ProfessionalBatchScreenState extends ConsumerState<ProfessionalBatchScreen> {
  final _controller = TextEditingController();
  final List<String> _ids = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addId() {
    final id = _controller.text.trim();
    if (id.isEmpty || _ids.contains(id)) return;
    setState(() => _ids.add(id));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Batch Verification'),
      ),
      body: Column(
        children: [
          // Capability header — PROFESSIONAL_CANNOT_SELECT_TIER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: PvColors.muted.withAlpha(20),
            child: Text(
              'Canonical trust projection only. Tier is server-determined. '
              'PROFESSIONAL_CANNOT_SELECT_TIER. '
              'Physical object matching: not available — PHYSICAL_MATCH_NOT_SUPPORTED.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              semanticsLabel:
                  'Professional mode: canonical trust projection only. Tier is server-determined. '
                  'Physical object matching: not available — not supported in any mode.',
            ),
          ),
          // ID entry row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Public Record ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addId(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addId,
                  style: FilledButton.styleFrom(
                    backgroundColor: PvColors.cyan,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_ids.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Add record IDs above to begin batch verification.',
                  style: TextStyle(color: PvColors.muted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _ids.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _BatchRow(publicId: _ids[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchRow extends ConsumerWidget {
  final String publicId;
  const _BatchRow({required this.publicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: trustAsync.when(
          loading: () => Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2,
                    semanticsLabel: 'Loading trust record'),
              ),
              const SizedBox(width: 12),
              Text(publicId, style: PvTypography.mono),
            ],
          ),
          error: (e, _) => _UnavailableRow(
            publicId: publicId,
            reason: 'Query failed — ${e.toString().split('\n').first}',
          ),
          data: (record) {
            final tier = record.safeTier;
            if (tier == null) {
              // Fail closed: UNQUALIFIED or no determination → AUTHORITY UNAVAILABLE
              return _UnavailableRow(
                publicId: publicId,
                reason: 'AUTHORITY UNAVAILABLE — do not rely on this record.',
              );
            }
            return _QualifiedRow(record: record, tier: tier);
          },
        ),
      ),
    );
  }
}

class _QualifiedRow extends StatelessWidget {
  final TrustRecord record;
  final int tier;
  const _QualifiedRow({required this.record, required this.tier});

  @override
  Widget build(BuildContext context) {
    final outcome = record.determination?.purchaseQualificationOutcome;
    final lifecycleStatus = record.lifecycle?.status?.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: PvColors.cyan.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'T$tier',
                style: PvTypography.label.copyWith(color: PvColors.cyan),
                semanticsLabel: 'Tier $tier — server-determined',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                record.publicId,
                style: PvTypography.mono,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (outcome != null) ...[
          const SizedBox(height: 6),
          Text(
            // MONEY_CONTROLS_TRUST = FALSE — server-authored qualification only
            'Commercial eligibility: $outcome',
            style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
            semanticsLabel: 'Commercial eligibility: $outcome — server-determined',
          ),
        ],
        if (lifecycleStatus != null && lifecycleStatus.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Lifecycle: $lifecycleStatus',
            style: PvTypography.bodySmall.copyWith(
              color: _lifecycleColor(lifecycleStatus),
            ),
          ),
        ],
      ],
    );
  }

  Color _lifecycleColor(String status) {
    switch (status) {
      case 'REVOKED':
      case 'SUSPENDED':
        return PvColors.error;
      case 'EXPIRED':
      case 'SUPERSEDED':
        return PvColors.warning;
      default:
        return PvColors.muted;
    }
  }
}

class _UnavailableRow extends StatelessWidget {
  final String publicId;
  final String reason;
  const _UnavailableRow({required this.publicId, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Authority unavailable for $publicId: $reason',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: PvColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  publicId,
                  style: PvTypography.mono,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: PvTypography.bodySmall.copyWith(color: PvColors.error),
          ),
        ],
      ),
    );
  }
}
