import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../receipt_models.dart';
import '../../actionability/actionability_models.dart';
import '../../core/storage/secure_storage.dart';

final secureStorageProvider = Provider<PvSecureStorage>((ref) => PvSecureStorage());

final receiptListProvider = FutureProvider<List<RelianceReceipt>>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final ids = await storage.listReceiptIds();
  final receipts = <RelianceReceipt>[];
  for (final id in ids) {
    final json = await storage.readReceiptJson(id);
    if (json != null) {
      try {
        receipts.add(RelianceReceipt.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (_) {}
    }
  }
  receipts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return receipts;
});

class ReceiptNotifier extends Notifier<AsyncValue<List<RelianceReceipt>>> {
  @override
  AsyncValue<List<RelianceReceipt>> build() => const AsyncValue.loading();

  Future<void> saveReceipt({
    required String publicId,
    required String physicalSubjectId,
    required String trustStateDigest,
    required ActionabilityPurpose purpose,
    required ActionabilityDecision decision,
    required List<String> limitations,
    required List<String> prohibitedInferences,
    String? policyVersion,
  }) async {
    final storage = ref.read(secureStorageProvider);
    final receipt = RelianceReceipt(
      receiptId: const Uuid().v4(),
      publicId: publicId,
      physicalSubjectId: physicalSubjectId,
      trustStateDigest: trustStateDigest,
      purpose: purpose,
      decision: decision,
      limitations: limitations,
      prohibitedInferences: prohibitedInferences,
      createdAt: DateTime.now().toUtc(),
      validityState: ReceiptValidityState.valid,
      policyVersion: policyVersion,
    );
    await storage.saveReceiptJson(receipt.receiptId, jsonEncode(receipt.toJson()));
    ref.invalidate(receiptListProvider);
  }
}

final receiptNotifierProvider =
    NotifierProvider<ReceiptNotifier, AsyncValue<List<RelianceReceipt>>>(ReceiptNotifier.new);
