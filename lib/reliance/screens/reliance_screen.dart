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
    final actionAsync = ref.watch(simpleActionabilityProvider(args));
    final trustAsync = ref.watch(trustRecordProvider(widget.publicId));

    // Stale-state law: REVOKED/SUSPENDED records block reliance entirely.
    // LOCAL CACHE IS NEVER CURRENT TRUST AUTHORITY — always use fresh server data.
    final lifecycleStatus = trustAsync.valueOrNull?.lifecycle?.status?.toUpperCase();
    const _blockedLifecycles = {'REVOKED', 'SUSPENDED'};
    final lifecycleBlocked = _blockedLifecycles.contains(lifecycleStatus);
    final lifecycleWarning = lifecycleStatus == 'EXPIRED' || lifecycleStatus == 'SUPERSEDED';

    return Scaffold(
      appBar: AppBar(title: const Text('Reliance Assessment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lifecycleBlocked)
            Semantics(
              label: 'Reliance blocked: record is $lifecycleStatus. Do not rely.',
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PvColors.error.withAlpha(30),
                  border: Border.all(color: PvColors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: PvColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'RELIANCE BLOCKED — This record is $lifecycleStatus. '
                        'Do not use it as a basis for any reliance decision.',
                        style: PvTypography.body.copyWith(color: PvColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (lifecycleWarning)
            Semantics(
              label: 'Warning: record is $lifecycleStatus. Requery before relying.',
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PvColors.warning.withAlpha(30),
                  border: Border.all(color: PvColors.warning),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.update, color: PvColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$lifecycleStatus — Requery this record before relying on it.',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            error: (e, _) => Semantics(
              label: 'Error querying actionability: ${e.toString()}',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PvColors.error.withAlpha(20),
                  border: Border.all(color: PvColors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: PvColors.error, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Could not query actionability.',
                            style: TextStyle(color: PvColors.error),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: PvTypography.bodySmall
                          .copyWith(color: PvColors.muted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final args =
                            (publicId: widget.publicId, purpose: _purpose.toJson());
                        ref.invalidate(simpleActionabilityProvider(args));
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
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
                      onPressed: isUnknown || _saving || lifecycleBlocked
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
                      style: FilledButton.styleFrom(backgroundColor: PvColors.cyan, foregroundColor: Colors.black),
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
    if (record == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trust record not yet loaded. Please wait and try again.'),
            backgroundColor: PvColors.error,
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final notifier = ref.read(receiptNotifierProvider.notifier);
      final receipt = await notifier.saveReceipt(
        publicId: widget.publicId,
        physicalSubjectId: record.subject.physicalSubjectId,
        trustStateDigest: record.trustStateDigest,
        purpose: _purpose,
        decision: result.decision,
        limitations: result.limitations,
        prohibitedInferences: result.prohibitedInferences,
        policyVersion: result.policyVersion,
      );
      if (mounted) setState(() => _savedReceiptId = receipt.receiptId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save receipt: $e'), backgroundColor: PvColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
