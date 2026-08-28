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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
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
                        child: Text(
                          'This record has achieved the Gold Standard (Tier 4). '
                          'No further tier advancement is possible.',
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
