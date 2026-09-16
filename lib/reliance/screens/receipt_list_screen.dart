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
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading reliance receipts'),
        ),
        error: (e, _) => _ErrorView(error: e, ref: ref),
        data: (receipts) {
          if (receipts.isEmpty) {
            return Center(
              child: Text(
                'No receipts saved yet.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
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
      onTap: () => context.push('/my-pv/receipts/${receipt.receiptId}'),
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

class _ErrorView extends StatelessWidget {
  final Object error;
  final WidgetRef ref;
  const _ErrorView({required this.error, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Could not load receipts. Retry.',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: PvColors.error, size: 48),
              const SizedBox(height: 16),
              const Text('Could not load receipts', style: PvTypography.title),
              const SizedBox(height: 8),
              Text(
                'Check your connection and retry.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(receiptListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PvColors.onBackground,
                  side: const BorderSide(color: PvColors.border),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
