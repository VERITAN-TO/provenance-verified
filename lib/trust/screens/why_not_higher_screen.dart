import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class WhyNotHigherScreen extends ConsumerWidget {
  final String publicId;
  const WhyNotHigherScreen({super.key, required this.publicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));
    return Scaffold(
      appBar: AppBar(title: const Text('Why Not Higher?')),
      body: trustAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading tier requirements'),
        ),
        error: (e, _) => Semantics(
          label: 'Could not load tier requirements.',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: PvColors.error, size: 48),
                  const SizedBox(height: 16),
                  const Text('Could not load tier requirements', style: PvTypography.title),
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
        data: (record) {
          final unmet = record.determination?.notMetRequirements ?? [];
          final tier = record.safeTier ?? 0;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (tier == 4)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PvColors.tier4.withAlpha(20),
                    border: Border.all(color: PvColors.tier4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: PvColors.tier4),
                      const SizedBox(width: 12),
                      const Expanded(
                        // T4_DETERMINATION_IS_OFFICIAL_T4=FALSE; GOLD_SEAL_REQUIRES_SEPARATE_AUTHORITY=TRUE
                        child: Text(
                          'This record has achieved T4 — Highest Governed Provenance Authority. '
                          'No further tier advancement is possible. '
                          'T4 determination is separate from Gold Seal issuance.',
                          style: TextStyle(color: PvColors.onBackground),
                        ),
                      ),
                    ],
                  ),
                )
              else if (unmet.isEmpty)
                Text(
                  'Requirements for the next tier are not yet available for this record.',
                  style: PvTypography.body,
                )
              else ...[
                Text(
                  'UNMET REQUIREMENTS FOR TIER ${tier + 1}',
                  style: PvTypography.label.copyWith(color: PvColors.muted),
                ),
                const SizedBox(height: 16),
                ...unmet.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.remove_circle_outline, color: PvColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r, style: PvTypography.body)),
                    ],
                  ),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}
