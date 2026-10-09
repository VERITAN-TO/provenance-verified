// ServiceTierCard — educational PV trust-ladder card.
//
// T1–T4 are resulting trust states, never customer-selectable products.
// Evidence + deterministic policy determine the highest supported tier.

import 'package:flutter/material.dart';
import '../models/submit_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ServiceTierCard extends StatelessWidget {
  final ServiceTier tier;

  const ServiceTierCard({
    super.key,
    required this.tier,
  });

  Color get _tierAccent {
    switch (tier) {
      case ServiceTier.t1Free: return PvColors.tier1;
      case ServiceTier.t2Standard: return PvColors.tier2;
      case ServiceTier.t3Professional: return PvColors.tier3;
      case ServiceTier.t4Certified: return PvColors.tier4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _tierAccent;
    return Semantics(
      label: '${tier.displayName}: ${tier.shortDescription}. ${tier.machineTrustState}. Settlement: ${tier.priceRange}.',
      child: Container(
        decoration: BoxDecoration(
          color: PvColors.background,
          border: Border.all(color: PvColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    border: Border.all(color: accent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tier.apiValue, style: PvTypography.label.copyWith(color: accent)),
                ),
                const Spacer(),
                Text(tier.priceRange, style: PvTypography.title.copyWith(color: PvColors.silver, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tier.displayName.replaceFirst('${tier.apiValue} — ', ''),
              style: PvTypography.title.copyWith(color: PvColors.onBackground, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(tier.shortDescription, style: PvTypography.body.copyWith(color: PvColors.onSurface)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withAlpha(16),
                border: Border.all(color: accent.withAlpha(80)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MACHINE TRUST STATE', style: PvTypography.label.copyWith(color: accent)),
                  const SizedBox(height: 4),
                  Text(tier.machineTrustState, style: PvTypography.bodySmall.copyWith(color: PvColors.onSurface)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...tier.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: PvTypography.bodySmall.copyWith(color: PvColors.onSurface))),
                ],
              ),
            )),
            const SizedBox(height: 10),
            Text(
              'Your evidence determines whether this state is earned.',
              style: PvTypography.bodySmall.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
