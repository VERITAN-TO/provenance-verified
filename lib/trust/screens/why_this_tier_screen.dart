import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class WhyThisTierScreen extends ConsumerWidget {
  final String publicId;
  const WhyThisTierScreen({super.key, required this.publicId});

  String _tierExplanation(TrustRecord record) {
    if (!record.isQualified) {
      final state = record.determination?.qualificationState;
      return 'This record is NOT QUALIFIED. '
          '${state != null ? "Qualification state: ${state.name.toUpperCase()}." : ""} '
          'This means the record does not meet the criteria for any trust tier.';
    }
    final tier = record.safeTier;
    switch (tier) {
      case 1:
        return 'Tier 1 — Asset Fingerprint: The record establishes the identity of '
            'the subject through physical or digital fingerprint characteristics. '
            'Claims are registered but not yet independently verified.';
      case 2:
        return 'Tier 2 — Declared Provenance: The origin and history are declared by '
            'the submitting party. Claims are asserted but evidence is from the '
            'submitting party itself (related party).';
      case 3:
        return 'Tier 3 — Evidence-Verified: Independent third-party evidence supports '
            'the declared claims. The evidence has been verified for integrity.';
      case 4:
        // T4_DETERMINATION_IS_OFFICIAL_T4=FALSE; GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE
        return 'T4 — Highest Governed Provenance Authority: All claims are supported '
            'by independent, integrity-verified evidence. Continuous custody is '
            'established with no material gaps. T4 determination alone does not '
            'issue a Gold Seal; separate signing, registry, and mark gates apply.';
      default:
        return 'Tier information not available.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));
    return Scaffold(
      appBar: AppBar(title: const Text('Why This Tier?')),
      body: trustAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading tier explanation'),
        ),
        error: (e, _) => Semantics(
          label: 'Could not load tier explanation.',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: PvColors.error, size: 48),
                  const SizedBox(height: 16),
                  const Text('Could not load tier explanation', style: PvTypography.title),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(trustRecordProvider(publicId)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (record) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PvColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _tierExplanation(record),
                style: PvTypography.body,
              ),
            ),
            const SizedBox(height: 24),
            if (record.determination?.metRequirements.isNotEmpty == true) ...[
              Text('MET REQUIREMENTS', style: PvTypography.label.copyWith(color: PvColors.success)),
              const SizedBox(height: 8),
              ...record.determination!.metRequirements.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: PvColors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, style: PvTypography.bodySmall)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
