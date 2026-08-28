import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reliance_provider.dart';
import '../receipt_models.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ReceiptListScreen extends ConsumerWidget {
  const ReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reliance Receipts')),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (receipts) {
          if (receipts.isEmpty) {
            return const Center(
              child: Text(
                'No receipts saved yet.',
                style: TextStyle(color: PvColors.muted),
              ),
            );
          }
          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, i) {
              final r = receipts[i];
              return _ReceiptTile(receipt: r);
            },
          );
        },
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final RelianceReceipt receipt;
  const _ReceiptTile({required this.receipt});

  Color _validityColor(ReceiptValidityState s) {
    switch (s) {
      case ReceiptValidityState.valid: return PvColors.success;
      case ReceiptValidityState.invalidated: return PvColors.error;
      case ReceiptValidityState.expired: return PvColors.warning;
      case ReceiptValidityState.unknown: return PvColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _validityColor(receipt.validityState);
    return ListTile(
      onTap: () => context.push('/receipts/${receipt.receiptId}'),
      title: Text(receipt.publicId, style: PvTypography.body),
      subtitle: Text(
        receipt.purpose.displayLabel,
        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
      ),
      trailing: Semantics(
        label: 'Receipt validity: ${receipt.validityState.name}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            receipt.validityState.name.toUpperCase(),
            style: PvTypography.label.copyWith(color: color, fontSize: 9),
          ),
        ),
      ),
    );
  }
}
