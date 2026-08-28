import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class StaleBanner extends StatelessWidget {
  final FreshnessState freshness;
  final VoidCallback? onRequery;
  const StaleBanner({super.key, required this.freshness, this.onRequery});

  @override
  Widget build(BuildContext context) {
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
