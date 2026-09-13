// Submit provider — manages wizard state and backend communication.
//
// MONEY_CONTROLS_TRUST = FALSE: Payment is a prerequisite to process,
// not a factor in trust determination. The trust tier is determined
// exclusively by the backend after evidence review.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/submit_models.dart';
import '../../core/config/environment.dart';
import '../../auth/providers/auth_provider.dart';
import 'payment_coordinator.dart';
import 'submit_api_exception.dart';

class SubmissionApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String? Function() _getToken;
  final Future<String?> Function() _refreshToken;

  SubmissionApiClient({
    http.Client? client,
    String? baseUrl,
    required String? Function() getToken,
    required Future<String?> Function() refreshToken,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _getToken = getToken,
        _refreshToken = refreshToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = await _refreshToken();
    if (token == null || token.isEmpty) throw Exception('Session refresh failed');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final nested = decoded['error'];
      if (nested is Map<String, dynamic>) {
        return {
          ...decoded,
          'message': nested['message']?.toString() ?? nested['code']?.toString(),
        };
      }
      return decoded;
    } catch (_) {
      return {'message': res.reasonPhrase ?? 'Unknown error'};
    }
  }

  Future<Map<String, dynamic>> startSubmission({required String serviceTier}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/start');
    final body = jsonEncode({'requested_service_tier': serviceTier});
    var res = await _client.post(uri, headers: await _authHeaders(), body: body).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.post(uri, headers: await _refreshedHeaders(), body: body).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Start failed');
  }

  Future<void> saveAssetInfo({required String submissionId, required Map<String, dynamic> payload}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/asset-info');
    final body = jsonEncode(payload);
    var res = await _client.post(uri, headers: await _authHeaders(), body: body).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.post(uri, headers: await _refreshedHeaders(), body: body).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Asset info save failed');
  }

  Future<void> uploadEvidence({
    required String submissionId,
    required String filePath,
    required String fileName,
    required String docType,
  }) async {
    Future<http.Response> send(String token) async {
      final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/evidence');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['document_type'] = docType
        ..files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }

    var token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    var res = await send(token);
    if (res.statusCode == 401) {
      token = await _refreshToken();
      if (token == null || token.isEmpty) throw Exception('Session refresh failed');
      res = await send(token);
    }
    if (res.statusCode == 200 || res.statusCode == 201) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Evidence upload failed');
  }

  Future<void> saveDeclarations({required String submissionId, required Map<String, dynamic> payload}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/declarations');
    final body = jsonEncode(payload);
    var res = await _client.post(uri, headers: await _authHeaders(), body: body).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.post(uri, headers: await _refreshedHeaders(), body: body).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Declarations save failed');
  }

  Future<Map<String, dynamic>> getQuote(String submissionId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/quote');
    var res = await _client.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) {
      res = await _client.get(uri, headers: await _refreshedHeaders()).timeout(const Duration(seconds: 30));
    }
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Quote fetch failed');
  }

  String? getToken() => _getToken();
  void dispose() => _client.close();
}

final submissionApiClientProvider = Provider<SubmissionApiClient>((ref) {
  final c = SubmissionApiClient(
    getToken: () => ref.read(authProvider)?.accessToken,
    refreshToken: () async {
      await ref.read(authProvider.notifier).refresh();
      return ref.read(authProvider)?.accessToken;
    },
  );
  ref.onDispose(c.dispose);
  return c;
});

class SubmitNotifier extends StateNotifier<SubmissionDraft?> {
  final SubmissionApiClient _api;
  final PaymentCoordinator _payment;
  SubmitNotifier(this._api, this._payment) : super(null);

  void reset() => state = null;
  void beginNew() => state = const SubmissionDraft(step: 0);

  void selectTier(ServiceTier tier) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(selectedTier: tier);
  }
  void updateAssetName(String name) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(assetName: name);
  }
  void updateAssetType(String type) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(assetType: type);
  }
  void updateGemstoneAttributes(GemstoneAttributes attrs) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(gemstoneAttributes: attrs);
  }
  void addPhoto(String path) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(photoPaths: [...current.photoPaths, path]);
  }
  void removePhoto(String path) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(photoPaths: current.photoPaths.where((p) => p != path).toList());
  }
  void addDocument(EvidenceDocument doc) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(documents: [...current.documents, doc]);
  }
  void removeDocument(int index) {
    final current = state ?? const SubmissionDraft(step: 0);
    final docs = List<EvidenceDocument>.from(current.documents);
    if (index >= 0 && index < docs.length) docs.removeAt(index);
    state = current.copyWith(documents: docs);
  }
  void markDocumentUploaded(int index) {
    final current = state ?? const SubmissionDraft(step: 0);
    final docs = List<EvidenceDocument>.from(current.documents);
    if (index >= 0 && index < docs.length) docs[index] = docs[index].copyWith(uploaded: true);
    state = current.copyWith(documents: docs);
  }
  void updateDocumentType(int index, EvidenceDocumentType docType) {
    final current = state ?? const SubmissionDraft(step: 0);
    final docs = List<EvidenceDocument>.from(current.documents);
    if (index >= 0 && index < docs.length) docs[index] = docs[index].copyWith(docType: docType);
    state = current.copyWith(documents: docs);
  }
  void setDeclaredAccurate(bool value) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(declaredAccurate: value);
  }
  void setDeclaredTierMayDiffer(bool value) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(declaredTierMayDiffer: value);
  }
  void setDeclaredTermsAgreed(bool value) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(declaredTermsAgreed: value);
  }
  void goToStep(int step) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(step: step);
  }

  Future<void> startSubmission() async {
    final current = state;
    if (current == null || current.selectedTier == null) throw StateError('No tier selected');
    final result = await _api.startSubmission(serviceTier: current.selectedTier!.apiValue);
    state = current.copyWith(
      submissionId: result['submission_id'] as String?,
      orderId: result['order_id'] as String?,
      step: 1,
    );
  }

  Future<void> saveAssetInfo() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    await _api.saveAssetInfo(
      submissionId: current.submissionId!,
      payload: {
        'asset_name': current.assetName,
        'asset_type': current.assetType,
        'gemstone_attributes': current.gemstoneAttributes.toJson(),
      },
    );
  }

  Future<void> uploadPendingDocuments() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    for (int i = 0; i < current.documents.length; i++) {
      final doc = current.documents[i];
      if (!doc.uploaded) {
        await _api.uploadEvidence(
          submissionId: current.submissionId!,
          filePath: doc.filePath,
          fileName: doc.fileName,
          docType: doc.docType.apiValue,
        );
        markDocumentUploaded(i);
      }
    }
  }

  Future<void> saveDeclarations() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    await _api.saveDeclarations(
      submissionId: current.submissionId!,
      payload: {
        'declared_accurate': current.declaredAccurate,
        'declared_tier_may_differ': current.declaredTierMayDiffer,
        'declared_terms_agreed': current.declaredTermsAgreed,
      },
    );
  }

  Future<SubmissionQuote> fetchQuote() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    final json = await _api.getQuote(current.submissionId!);
    return SubmissionQuote.fromJson(json);
  }

  /// Uses the existing wizard seam but delegates authority to the canonical
  /// claimant-identity + order/payment coordinator. The caller remains on the
  /// checkout step while external identity/payment work is pending, then taps
  /// again after returning to reconcile the provider state and finalize.
  Future<Map<String, dynamic>> checkout({bool testMode = false}) async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');

    final identity = await _payment.claimantIdentityStatus();
    if (!identity.verified) {
      final launched = await _payment.launchClaimantIdentityVerification();
      if (!launched) {
        throw const SubmitApiException(502, 'Could not open identity verification.');
      }
      throw const SubmitApiException(
        428,
        'Complete government-ID + matching-selfie verification, return to PROVENANCE VERIFIED, then tap Continue again.',
      );
    }

    var orderId = current.orderId;
    if (orderId == null || orderId.isEmpty) {
      final quote = await fetchQuote();
      final order = await _payment.createOrder(submissionId: current.submissionId!, quote: quote);
      orderId = order.orderId;
      state = (state ?? current).copyWith(orderId: orderId);

      if (order.checkoutUrl != null) {
        final launched = await _payment.launchCheckout(order);
        if (!launched) throw const SubmitApiException(502, 'Could not open secure checkout.');
        throw const SubmitApiException(
          202,
          'Complete secure payment, return to PROVENANCE VERIFIED, then tap Continue again to reconcile and submit.',
        );
      }
    }

    final quote = await fetchQuote();
    if (quote.paymentRequired) {
      final paymentStatus = await _payment.paymentStatus(orderId);
      if (paymentStatus != 'PAID') {
        throw SubmitApiException(202, 'Payment status is $paymentStatus. Complete payment, then try again.');
      }
    }

    final result = await _payment.finalize(submissionId: current.submissionId!, orderId: orderId);
    return result;
  }
}

final submitProvider = StateNotifierProvider<SubmitNotifier, SubmissionDraft?>((ref) {
  final api = ref.watch(submissionApiClientProvider);
  final payment = ref.watch(paymentCoordinatorProvider);
  return SubmitNotifier(api, payment);
});
