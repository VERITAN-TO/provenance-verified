import 'package:flutter/material.dart';
import '../trust_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class EvidenceList extends StatelessWidget {
  final List<EvidenceItem> evidence;
  const EvidenceList({super.key, required this.evidence});

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      return const Text('No evidence recorded', style: TextStyle(color: PvColors.muted));
    }
    return Column(
      children: evidence.map((e) {
        final isRelated = e.relatedParty.isRelated;
        return Semantics(
          label: '${e.type}, ${isRelated ? "related party" : "independent"}',
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.type, style: PvTypography.body)),
                      if (isRelated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PvColors.warning.withAlpha(40),
                            border: Border.all(color: PvColors.warning),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RELATED PARTY',
                            style: PvTypography.label.copyWith(color: PvColors.warning),
                            semanticsLabel: 'Related party evidence',
                          ),
                        ),
                    ],
                  ),
                  if (e.source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Issuer: ${e.source}', style: PvTypography.bodySmall),
                    ),
                  if (e.integrityVerificationState == IntegrityVerificationState.verified)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 14, color: PvColors.success),
                          const SizedBox(width: 4),
                          Text('Integrity verified', style: PvTypography.bodySmall.copyWith(color: PvColors.success)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
