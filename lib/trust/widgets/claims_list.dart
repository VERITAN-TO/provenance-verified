import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ClaimsList extends StatelessWidget {
  final List<ClaimVerdict> claims;
  const ClaimsList({super.key, required this.claims});

  Color _stateColor(ClaimState s) {
    if (s.isPositive) return PvColors.success;
    if (s.isNegative) return PvColors.error;
    return PvColors.muted;
  }

  IconData _stateIcon(ClaimState s) {
    if (s == ClaimState.supported) return Icons.check_circle_outline;
    if (s == ClaimState.contradicted) return Icons.cancel_outlined;
    if (s == ClaimState.insufficient) return Icons.warning_amber_outlined;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return const Text('No claims recorded', style: TextStyle(color: PvColors.muted));
    }
    return Column(
      children: claims.map((c) {
        final color = _stateColor(c.claimState);
        return Semantics(
          label: '${c.predicate}: ${c.claimState.name}',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_stateIcon(c.claimState), color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.predicate, style: PvTypography.body),
                      Text(
                        c.claimState.name.toUpperCase(),
                        style: PvTypography.label.copyWith(color: color),
                      ),
                      if (c.assertedValue.isNotEmpty)
                        Text(c.assertedValue, style: PvTypography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
