import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../actionability_models.dart';
import '../providers/actionability_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ActionabilityScreen extends ConsumerStatefulWidget {
  final String publicId;
  const ActionabilityScreen({super.key, required this.publicId});

  @override
  ConsumerState<ActionabilityScreen> createState() => _ActionabilityScreenState();
}

class _ActionabilityScreenState extends ConsumerState<ActionabilityScreen> {
  ActionabilityPurpose _purpose = ActionabilityPurpose.purchase;

  Color _decisionColor(ActionabilityDecision d) {
    switch (d) {
      case ActionabilityDecision.allow: return PvColors.success;
      case ActionabilityDecision.qualify: return PvColors.warning;
      case ActionabilityDecision.deny: return PvColors.error;
      // UNKNOWN must fail-closed — never render as ALLOW
      case ActionabilityDecision.unknown: return PvColors.error;
    }
  }

  String _decisionSemanticsLabel(ActionabilityDecision d) {
    if (d == ActionabilityDecision.unknown) {
      return 'UNKNOWN — Cannot assess actionability. Do not rely.';
    }
    return d.displayLabel;
  }

  @override
  Widget build(BuildContext context) {
    final args = (publicId: widget.publicId, purpose: _purpose.toJson());
    final actionAsync = ref.watch(simpleActionabilityProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assess Reliance'),
        actions: [
          TextButton(
            onPressed: actionAsync.hasValue
                ? () => context.push('/verify/${widget.publicId}/reliance',
                    extra: actionAsync.value)
                : null,
            child: const Text('Save Receipt'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ActionabilityPurpose>(
            // ignore: deprecated_member_use
            value: _purpose,
            decoration: const InputDecoration(
              labelText: 'Purpose of Reliance',
              border: OutlineInputBorder(),
            ),
            items: ActionabilityPurpose.values
                .where((p) => p != ActionabilityPurpose.custom)
                .map((p) => DropdownMenuItem(value: p, child: Text(p.displayLabel)))
                .toList(),
            onChanged: (p) {
              if (p != null) setState(() => _purpose = p);
            },
          ),
          const SizedBox(height: 24),
          actionAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Querying actionability from server',
              ),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PvColors.error.withAlpha(20),
                border: Border.all(color: PvColors.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unable to determine actionability: $e',
                style: const TextStyle(color: PvColors.error),
              ),
            ),
            data: (result) => _ResultView(result: result, decisionColor: _decisionColor, semanticsLabel: _decisionSemanticsLabel),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ActionabilityResult result;
  final Color Function(ActionabilityDecision) decisionColor;
  final String Function(ActionabilityDecision) semanticsLabel;

  const _ResultView({
    required this.result,
    required this.decisionColor,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = decisionColor(result.decision);
    final label = semanticsLabel(result.decision);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Actionability decision: $label',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result.decision == ActionabilityDecision.unknown
                  ? 'UNKNOWN — Do not rely'
                  : result.decision.displayLabel,
              style: PvTypography.headline.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (result.rationale != null) ...[
          const SizedBox(height: 16),
          Text('Rationale', style: PvTypography.label.copyWith(color: PvColors.muted)),
          const SizedBox(height: 6),
          Text(result.rationale!, style: PvTypography.body),
        ],
        if (result.qualifications.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Qualifications', style: PvTypography.label.copyWith(color: PvColors.warning)),
          const SizedBox(height: 6),
          ...result.qualifications.map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 14, color: PvColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(q, style: PvTypography.bodySmall)),
              ],
            ),
          )),
        ],
        if (result.limitations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Limitations', style: PvTypography.label.copyWith(color: PvColors.limitation)),
          const SizedBox(height: 6),
          ...result.limitations.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $l', style: PvTypography.bodySmall),
          )),
        ],
        if (result.prohibitedInferences.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Do Not Infer', style: PvTypography.label.copyWith(color: PvColors.prohibited)),
          const SizedBox(height: 6),
          ...result.prohibitedInferences.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.block, size: 14, color: PvColors.prohibited),
                const SizedBox(width: 8),
                Expanded(child: Text(p, style: PvTypography.bodySmall.copyWith(color: PvColors.prohibited))),
              ],
            ),
          )),
        ],
      ],
    );
  }
}
