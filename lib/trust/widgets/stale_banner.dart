import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

// ────────────────────────────────────────────────────────────────────────────
// StaleBanner — R31: approachingStale now surfaces a subtle advisory before
// the requiresRequery gate fires. Does NOT block reliance.
// ────────────────────────────────────────────────────────────────────────────

class StaleBanner extends StatelessWidget {
  final FreshnessState freshness;
  final VoidCallback? onRequery;
  const StaleBanner({super.key, required this.freshness, this.onRequery});

  @override
  Widget build(BuildContext context) {
    if (freshness == FreshnessState.approachingStale) {
      return _ApproachingStaleAdvisory(onRequery: onRequery);
    }
    if (!freshness.requiresRequery) return const SizedBox.shrink();
    final isExpired = freshness == FreshnessState.expired;
    final color = isExpired ? PvColors.error : PvColors.warning;
    final label = isExpired ? 'EXPIRED — Do not rely on this record' : 'STALE — Requery recommended';
    return Semantics(
      label: label,
      child: GestureDetector(
        onTap: onRequery,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.update, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: PvTypography.bodySmall.copyWith(color: color))),
              if (onRequery != null)
                Icon(Icons.refresh, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Approaching-stale advisory — R31.
// Shown for FreshnessState.approachingStale before requiresRequery fires.
// Subtle: muted color, does NOT block reliance or show error state.
// ────────────────────────────────────────────────────────────────────────────

class _ApproachingStaleAdvisory extends StatelessWidget {
  final VoidCallback? onRequery;
  const _ApproachingStaleAdvisory({this.onRequery});

  @override
  Widget build(BuildContext context) {
    const label = 'Verification due soon — requery to refresh';
    return Semantics(
      label: label,
      child: GestureDetector(
        onTap: onRequery,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: PvColors.muted.withAlpha(20),
            border: Border.all(color: PvColors.muted.withAlpha(80)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: PvColors.muted, size: 16),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: PvTypography.bodySmall.copyWith(color: PvColors.muted))),
              if (onRequery != null)
                const Icon(Icons.refresh, color: PvColors.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
