import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ContinuityWidget extends StatelessWidget {
  final TrustRecord record;
  const ContinuityWidget({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final continuity = record.continuity;
    if (continuity == null && !record.hasContinuityGap) return const SizedBox.shrink();
    final state = continuity?.state ?? record.subject.continuityState;
    final hasGap = record.hasContinuityGap;
    final gapDesc = continuity?.gapDescription;
    final color = hasGap ? PvColors.warning : PvColors.success;
    return Semantics(
      label: 'Custody continuity: ${state.name}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(hasGap ? Icons.link_off : Icons.link, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  'CUSTODY: ${state.name.toUpperCase()}',
                  style: PvTypography.label.copyWith(color: color),
                ),
              ],
            ),
            if (gapDesc != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(gapDesc, style: PvTypography.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
