// ServiceTierCard — displays one service tier option in the selection step.
//
// The tier shown is a REQUESTED SERVICE, not a guaranteed outcome.
// Trust determination is performed exclusively by the backend after review.

import 'package:flutter/material.dart';
import '../models/submit_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ServiceTierCard extends StatelessWidget {
  final ServiceTier tier;
  final bool isSelected;
  final VoidCallback onSelect;

  const ServiceTierCard({
    super.key,
    required this.tier,
    required this.isSelected,
    required this.onSelect,
  });

  Color get _tierAccent {
    switch (tier) {
      case ServiceTier.t1Free:          return PvColors.tier1;
      case ServiceTier.t2Standard:      return PvColors.tier2;
      case ServiceTier.t3Professional:  return PvColors.tier3;
      case ServiceTier.t4Certified:     return PvColors.tier4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent  = _tierAccent;
    final borderColor = isSelected ? accent : PvColors.border;

    return Semantics(
      label: '${tier.displayName}: ${tier.shortDescription}. Price: ${tier.priceRange}. '
          '${isSelected ? "Currently selected." : "Tap to select."}',
      button: !isSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? PvColors.surface : PvColors.background,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: isSelected ? null : onSelect,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(30),
                        border: Border.all(color: accent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tier.displayName.toUpperCase(),
                        style: PvTypography.label.copyWith(color: accent),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      tier.priceRange,
                      style: PvTypography.title.copyWith(
                        color: isSelected ? PvColors.onBackground : PvColors.silver,
                        fontSize: 15,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: accent, size: 20),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // ── Short description ───────────────────────────────────────
                Text(
                  tier.shortDescription,
                  style: PvTypography.body.copyWith(
                    color: PvColors.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Feature list ───────────────────────────────────────────
                ...tier.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f,
                            style: PvTypography.bodySmall.copyWith(
                              color: PvColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Select button ───────────────────────────────────────────
                if (!isSelected)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onSelect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Select'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: null, // already selected
                      style: FilledButton.styleFrom(
                        backgroundColor: accent.withAlpha(40),
                        foregroundColor: accent,
                        disabledBackgroundColor: accent.withAlpha(40),
                        disabledForegroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Selected'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
