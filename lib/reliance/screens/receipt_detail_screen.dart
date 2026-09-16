import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading receipt')),
        error: (e, _) => _BoundedErrorView(
          title: 'Could not load receipts',
          message: e.toString(),
          onRetry: () => ref.invalidate(receiptListProvider),
        ),
        data: (receipts) {
          final receipt = receipts.where((r) => r.receiptId == receiptId).firstOrNull;
          if (receipt == null) {
            return _BoundedNotFoundView(
              label: 'Receipt not found',
              message: 'No receipt found with ID "$receiptId".',
            );
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

class _BoundedErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  const _BoundedErrorView(
      {required this.title, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: PvColors.error, size: 48),
              const SizedBox(height: 16),
              Text(title, style: PvTypography.title),
              const SizedBox(height: 8),
              Text(message,
                  style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoundedNotFoundView extends StatelessWidget {
  final String label;
  final String message;
  const _BoundedNotFoundView({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, color: PvColors.muted, size: 48),
              const SizedBox(height: 16),
              Text(label, style: PvTypography.title),
              const SizedBox(height: 8),
              Text(message,
                  style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
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
