import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class TrustBadge extends StatelessWidget {
  final TrustRecord record;

  const TrustBadge({super.key, required this.record});

  Color _tierColor(int? tier) {
    switch (tier) {
      case 1: return PvColors.tier1;
      case 2: return PvColors.tier2;
      case 3: return PvColors.tier3;
      case 4: return PvColors.tier4;
      default: return PvColors.muted;
    }
  }

  String _tierLabel(TrustRecord r) {
    // M1-05 R2 Ambiguity Defense — NEVER expose T1 for UNQUALIFIED
    if (!r.isQualified) {
      return 'NOT QUALIFIED';
    }
    final tier = r.safeTier;
    if (tier == null) return 'NOT QUALIFIED';
    switch (tier) {
      case 1: return 'T1 ASSET FINGERPRINT';
      case 2: return 'T2 DECLARED PROVENANCE';
      case 3: return 'T3 EVIDENCE-VERIFIED';
      case 4: return 'T4 GOLD STANDARD';
      default: return 'TIER $tier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = record.safeTier;
    final color = _tierColor(tier);
    final label = _tierLabel(record);

    return Semantics(
      label: 'Trust tier: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: PvTypography.label.copyWith(
                    color: color,
                    letterSpacing: 1.2,
                  ),
                  semanticsLabel: label,
                ),
              ],
            ),
            if (record.hasContinuityGap)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'CUSTODY GAP',
                  style: PvTypography.label.copyWith(
                    color: PvColors.warning,
                    fontSize: 10,
                  ),
                  semanticsLabel: 'Custody gap present',
                ),
              ),
            if (record.hasConflict)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'MATERIAL CONFLICT',
                  style: PvTypography.label.copyWith(
                    color: PvColors.error,
                    fontSize: 10,
                  ),
                  semanticsLabel: 'Material conflict present',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
