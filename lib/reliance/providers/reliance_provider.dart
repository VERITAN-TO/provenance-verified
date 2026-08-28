// M2: Reliance receipt provider.
// Primary: server-side receipt via POST /api/v1/reliance-receipts (reliance:create scope).
// Fallback: local-only receipt in PvSecureStorage (when no server endpoint or offline).
// M1 Security Law: receipts are immutable once issued. Never cache for re-use.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../receipt_models.dart';
import '../../actionability/actionability_models.dart';
import '../../core/storage/secure_storage.dart';
import '../../trust/providers/trust_provider.dart';

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

  // Attempt server-side receipt creation, fall back to local.
  Future<RelianceReceipt> saveReceipt({
    required String publicId,
    required String physicalSubjectId,
    required String trustStateDigest,
    required ActionabilityPurpose purpose,
    required ActionabilityDecision decision,
    required List<String> limitations,
    required List<String> prohibitedInferences,
    String? policyVersion,
    bool tryServer = true,
  }) async {
    final storage = ref.read(secureStorageProvider);

    RelianceReceipt receipt;

    if (tryServer) {
      try {
        final client = ref.read(apiClientProvider);
        final serverResponse = await client.createRelianceReceipt(
          subjectId: publicId,
          purposeId: purpose.toJson(),
          requestedAction: 'evaluate',
          claimScope: 'standard',
        );
        receipt = _parseServerReceipt(
          serverResponse,
          publicId: publicId,
          physicalSubjectId: physicalSubjectId,
          trustStateDigest: trustStateDigest,
          purpose: purpose,
          limitations: limitations,
          prohibitedInferences: prohibitedInferences,
          policyVersion: policyVersion,
        );
      } catch (_) {
        // Fallback to local receipt on server failure.
        receipt = _buildLocalReceipt(
          publicId: publicId,
          physicalSubjectId: physicalSubjectId,
          trustStateDigest: trustStateDigest,
          purpose: purpose,
          decision: decision,
          limitations: limitations,
          prohibitedInferences: prohibitedInferences,
          policyVersion: policyVersion,
        );
      }
    } else {
      receipt = _buildLocalReceipt(
        publicId: publicId,
        physicalSubjectId: physicalSubjectId,
        trustStateDigest: trustStateDigest,
        purpose: purpose,
        decision: decision,
        limitations: limitations,
        prohibitedInferences: prohibitedInferences,
        policyVersion: policyVersion,
      );
    }

    await storage.saveReceiptJson(receipt.receiptId, jsonEncode(receipt.toJson()));
    ref.invalidate(receiptListProvider);
    return receipt;
  }

  RelianceReceipt _parseServerReceipt(
    Map<String, dynamic> json, {
    required String publicId,
    required String physicalSubjectId,
    required String trustStateDigest,
    required ActionabilityPurpose purpose,
    required List<String> limitations,
    required List<String> prohibitedInferences,
    String? policyVersion,
  }) {
    final decision = ActionabilityDecision.fromJson(json['decision']);
    final serverReceiptId = json['receipt_id'] as String? ?? const Uuid().v4();
    final serverTsd = json['trust_state_digest'] as String?;

    return RelianceReceipt(
      receiptId: serverReceiptId,
      publicId: publicId,
      physicalSubjectId: physicalSubjectId,
      trustStateDigest: serverTsd ?? trustStateDigest,
      purpose: purpose,
      decision: decision,
      limitations: (json['limitations'] as List?)?.map((e) => e.toString()).toList() ?? limitations,
      prohibitedInferences: (json['prohibited_inferences'] as List?)?.map((e) => e.toString()).toList() ?? prohibitedInferences,
      createdAt: DateTime.now().toUtc(),
      validityState: ReceiptValidityState.valid,
      policyVersion: json['policy_version'] as String? ?? policyVersion,
      isServerIssued: true,
    );
  }

  RelianceReceipt _buildLocalReceipt({
    required String publicId,
    required String physicalSubjectId,
    required String trustStateDigest,
    required ActionabilityPurpose purpose,
    required ActionabilityDecision decision,
    required List<String> limitations,
    required List<String> prohibitedInferences,
    String? policyVersion,
  }) => RelianceReceipt(
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
    isServerIssued: false,
  );
}

final receiptNotifierProvider =
    NotifierProvider<ReceiptNotifier, AsyncValue<List<RelianceReceipt>>>(ReceiptNotifier.new);
