import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class LimitationsWidget extends StatelessWidget {
  final List<TrustLimitation> limitations;
  const LimitationsWidget({super.key, required this.limitations});

  @override
  Widget build(BuildContext context) {
    if (limitations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIMITATIONS', style: PvTypography.label.copyWith(color: PvColors.limitation)),
        const SizedBox(height: 8),
        ...limitations.map((l) => Semantics(
          label: 'Limitation: ${l.code}',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: PvColors.limitation, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.code, style: PvTypography.label.copyWith(color: PvColors.limitation)),
                      if (l.message.isNotEmpty)
                        Text(l.message, style: PvTypography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
