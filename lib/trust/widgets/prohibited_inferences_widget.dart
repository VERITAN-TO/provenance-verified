import 'package:flutter/material.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ProhibitedInferencesWidget extends StatelessWidget {
  final List<String> prohibited;
  const ProhibitedInferencesWidget({super.key, required this.prohibited});

  @override
  Widget build(BuildContext context) {
    if (prohibited.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DO NOT INFER', style: PvTypography.label.copyWith(color: PvColors.prohibited)),
        const SizedBox(height: 8),
        ...prohibited.map((p) => Semantics(
          label: 'Do not infer: $p',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.block, color: PvColors.prohibited, size: 14),
                const SizedBox(width: 8),
                Text(p, style: PvTypography.bodySmall.copyWith(color: PvColors.prohibited)),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
