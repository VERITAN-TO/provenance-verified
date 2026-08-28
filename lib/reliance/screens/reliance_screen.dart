import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../trust/providers/trust_provider.dart';
import '../../actionability/actionability_models.dart';
import '../../actionability/providers/actionability_provider.dart';
import '../providers/reliance_provider.dart';
import '../../core/config/constants.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class RelianceScreen extends ConsumerStatefulWidget {
  final String publicId;
  const RelianceScreen({super.key, required this.publicId});

  @override
  ConsumerState<RelianceScreen> createState() => _RelianceScreenState();
}

class _RelianceScreenState extends ConsumerState<RelianceScreen> {
  ActionabilityPurpose _purpose = ActionabilityPurpose.purchase;
  bool _saving = false;
  String? _savedReceiptId;

  @override
  Widget build(BuildContext context) {
    // M1 Security Law: actionability NEVER cached for reliance — always fresh server query.
    assert(!PvConstants.actionabilityCacheForReliance, 'Actionability must not be cached for reliance');

    final args = (publicId: widget.publicId, purpose: _purpose.toJson());
    final actionAsync = ref.watch(actionabilityProvider(args));
    final trustAsync = ref.watch(trustRecordProvider(widget.publicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reliance Assessment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ActionabilityPurpose>(
            // ignore: deprecated_member_use
            value: _purpose,
            decoration: const InputDecoration(
              labelText: 'Purpose',
              border: OutlineInputBorder(),
            ),
            items: ActionabilityPurpose.values
                .where((p) => p != ActionabilityPurpose.custom)
                .map((p) => DropdownMenuItem(value: p, child: Text(p.displayLabel)))
                .toList(),
            onChanged: (p) {
              if (p != null) {
                setState(() {
                  _purpose = p;
                  _savedReceiptId = null;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          actionAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Querying actionability from server'),
            ),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: PvColors.error)),
            data: (result) {
              final isUnknown = result.decision == ActionabilityDecision.unknown;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isUnknown)
                    Semantics(
                      label: 'Warning: Actionability is UNKNOWN. Do not rely on this record.',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: PvColors.error.withAlpha(30),
                          border: Border.all(color: PvColors.error),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'UNKNOWN actionability — Do not rely on this record for the stated purpose.',
                          style: PvTypography.body.copyWith(color: PvColors.error),
                        ),
                      ),
                    ),
                  Text(
                    result.decision.displayLabel,
                    style: PvTypography.headline.copyWith(
                      color: _decisionColor(result.decision),
                    ),
                    semanticsLabel: 'Decision: ${result.decision.displayLabel}',
                  ),
                  if (result.rationale != null) ...[
                    const SizedBox(height: 12),
                    Text(result.rationale!, style: PvTypography.body),
                  ],
                  const SizedBox(height: 24),
                  if (_savedReceiptId != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PvColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Receipt saved: $_savedReceiptId',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.success),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: isUnknown || _saving
                          ? null
                          : () => _saveReceipt(result, trustAsync.value),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save Reliance Receipt'),
                      style: FilledButton.styleFrom(backgroundColor: PvColors.tier3),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _decisionColor(ActionabilityDecision d) {
    switch (d) {
      case ActionabilityDecision.allow: return PvColors.success;
      case ActionabilityDecision.qualify: return PvColors.warning;
      case ActionabilityDecision.deny: return PvColors.error;
      case ActionabilityDecision.unknown: return PvColors.error;
    }
  }

  Future<void> _saveReceipt(dynamic result, dynamic record) async {
    if (record == null) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(receiptNotifierProvider.notifier);
      await notifier.saveReceipt(
        publicId: widget.publicId,
        physicalSubjectId: record.subject.physicalSubjectId,
        trustStateDigest: record.trustStateDigest,
        purpose: _purpose,
        decision: result.decision,
        limitations: result.limitations,
        prohibitedInferences: result.prohibitedInferences,
        policyVersion: result.policyVersion,
      );
      setState(() => _savedReceiptId = 'saved');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: PvColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
