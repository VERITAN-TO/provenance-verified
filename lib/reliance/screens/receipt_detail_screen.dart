import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reliance_provider.dart';
import '../receipt_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  final String receiptId;
  const ReceiptDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Detail')),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (receipts) {
          final receipt = receipts.where((r) => r.receiptId == receiptId).firstOrNull;
          if (receipt == null) {
            return const Center(child: Text('Receipt not found'));
          }
          final isInvalidated = receipt.validityState != ReceiptValidityState.valid;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isInvalidated)
                Semantics(
                  label: 'Receipt is ${receipt.validityState.name}',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: PvColors.error.withAlpha(30),
                      border: Border.all(color: PvColors.error),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'This receipt is ${receipt.validityState.name.toUpperCase()}. '
                      'Do not rely on it for current decisions.',
                      style: PvTypography.body.copyWith(color: PvColors.error),
                    ),
                  ),
                ),
              _Row('Record', receipt.publicId),
              _Row('Purpose', receipt.purpose.displayLabel),
              _Row('Decision', receipt.decision.displayLabel),
              _Row('Digest', receipt.trustStateDigest),
              _Row('Created', receipt.createdAt.toLocal().toIso8601String()),
              if (receipt.validUntil != null)
                _Row('Valid until', receipt.validUntil!.toLocal().toIso8601String()),
              if (receipt.policyVersion != null)
                _Row('Policy', receipt.policyVersion!),
              if (receipt.limitations.isNotEmpty) ...[
                const Divider(height: 32),
                Text('LIMITATIONS', style: PvTypography.label.copyWith(color: PvColors.muted)),
                const SizedBox(height: 8),
                ...receipt.limitations.map((l) => Text('• $l', style: PvTypography.bodySmall)),
              ],
              if (receipt.prohibitedInferences.isNotEmpty) ...[
                const Divider(height: 32),
                Text('DO NOT INFER', style: PvTypography.label.copyWith(color: PvColors.prohibited)),
                const SizedBox(height: 8),
                ...receipt.prohibitedInferences.map((p) => Text('• $p', style: PvTypography.bodySmall.copyWith(color: PvColors.prohibited))),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
          ),
          Expanded(child: SelectableText(value, style: PvTypography.body)),
        ],
      ),
    );
  }
}
