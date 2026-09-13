// Submit provider — manages the existing M4 wizard and backend communication.
//
// CUSTOMER_SELECTS_TIER = FALSE
// MONEY_CONTROLS_TRUST = FALSE
// VERIFIED_HUMAN_CLAIMANT_REQUIRED = TRUE
// Evidence/policy determine tier; billing follows determination.

export 'submit_api_exception.dart';

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

  SubmissionApiClient({http.Client? client, String? baseUrl, required String? Function() getToken, required Future<String?> Function() refreshToken})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _getToken = getToken,
        _refreshToken = refreshToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = _getToken();
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = await _refreshToken();
    if (token == null || token.isEmpty) throw Exception('Session refresh failed');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final nested = decoded['error'];
      if (nested is Map<String, dynamic>) return {...decoded, 'message': nested['message']?.toString() ?? nested['code']?.toString()};
      return decoded;
    } catch (_) {
      return {'message': res.reasonPhrase ?? 'Unknown error'};
    }
  }

  Future<http.Response> _postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encoded = jsonEncode(body);
    var res = await _client.post(uri, headers: await _authHeaders(), body: encoded).timeout(const Duration(seconds: 60));
    if (res.statusCode == 401) res = await _client.post(uri, headers: await _refreshedHeaders(), body: encoded).timeout(const Duration(seconds: 60));
    return res;
  }

  Future<Map<String, dynamic>> startSubmission() async {
    final res = await _postJson('/api/v1/customer/submissions/start', const {});
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Start failed');
  }

  Future<void> saveAssetInfo({required String submissionId, required Map<String, dynamic> payload}) async {
    final res = await _postJson('/api/v1/customer/submissions/$submissionId/asset-info', payload);
    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Asset info save failed');
  }

  Future<void> uploadEvidence({required String submissionId, required String filePath, required String fileName, required String docType}) async {
    Future<http.Response> send(String token) async {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/evidence'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['document_type'] = docType
        ..files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      return http.Response.fromStream(await request.send().timeout(const Duration(seconds: 60)));
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
    final res = await _postJson('/api/v1/customer/submissions/$submissionId/declarations', payload);
    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Declarations save failed');
  }

  Future<Map<String, dynamic>> submitForEvaluation(String submissionId) async {
    final res = await _postJson('/api/v1/customer/submissions/$submissionId/submit', const {});
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'PV evaluation submission failed');
  }

  Future<Map<String, dynamic>> getQuote(String submissionId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/quote');
    var res = await _client.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 30));
    if (res.statusCode == 401) res = await _client.get(uri, headers: await _refreshedHeaders()).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Determination/quote is not ready');
  }

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

  @Deprecated('Tiers are educational/result states; customers do not select them.')
  void selectTier(ServiceTier tier) {}

  void updateAssetName(String name) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(assetName: name); }
  void updateAssetType(String type) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(assetType: type); }
  void updateGemstoneAttributes(GemstoneAttributes attrs) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(gemstoneAttributes: attrs); }
  void addPhoto(String path) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(photoPaths: [...c.photoPaths, path]); }
  void removePhoto(String path) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(photoPaths: c.photoPaths.where((p) => p != path).toList()); }
  void addDocument(EvidenceDocument doc) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(documents: [...c.documents, doc]); }
  void removeDocument(int index) { final c = state ?? const SubmissionDraft(step: 0); final docs = List<EvidenceDocument>.from(c.documents); if (index >= 0 && index < docs.length) docs.removeAt(index); state = c.copyWith(documents: docs); }
  void markDocumentUploaded(int index) { final c = state ?? const SubmissionDraft(step: 0); final docs = List<EvidenceDocument>.from(c.documents); if (index >= 0 && index < docs.length) docs[index] = docs[index].copyWith(uploaded: true); state = c.copyWith(documents: docs); }
  void updateDocumentType(int index, EvidenceDocumentType docType) { final c = state ?? const SubmissionDraft(step: 0); final docs = List<EvidenceDocument>.from(c.documents); if (index >= 0 && index < docs.length) docs[index] = docs[index].copyWith(docType: docType); state = c.copyWith(documents: docs); }
  void setDeclaredAccurate(bool value) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(declaredAccurate: value); }
  void setDeclaredTierMayDiffer(bool value) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(declaredTierMayDiffer: value); }
  void setDeclaredTermsAgreed(bool value) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(declaredTermsAgreed: value); }
  void goToStep(int step) { final c = state ?? const SubmissionDraft(step: 0); state = c.copyWith(step: step); }

  Future<void> startSubmission() async {
    final current = state ?? const SubmissionDraft(step: 0);
    final result = await _api.startSubmission();
    state = current.copyWith(submissionId: result['submission_id'] as String?, orderId: null, step: 1);
  }

  Future<void> saveAssetInfo() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    await _api.saveAssetInfo(submissionId: current.submissionId!, payload: {
      'asset_name': current.assetName,
      'asset_type': current.assetType,
      'gemstone_attributes': current.gemstoneAttributes.toJson(),
    });
  }

  Future<void> uploadPendingDocuments() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    for (int i = 0; i < current.documents.length; i++) {
      final doc = current.documents[i];
      if (!doc.uploaded) {
        await _api.uploadEvidence(submissionId: current.submissionId!, filePath: doc.filePath, fileName: doc.fileName, docType: doc.docType.apiValue);
        markDocumentUploaded(i);
      }
    }
  }

  Future<void> saveDeclarations() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    await _api.saveDeclarations(submissionId: current.submissionId!, payload: {
      'declared_accurate': current.declaredAccurate,
      'declared_tier_may_differ': current.declaredTierMayDiffer,
      'declared_terms_agreed': current.declaredTermsAgreed,
    });
  }

  Future<Map<String, dynamic>> submitForEvaluation() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    await _payment.ensureClaimantIdentity();
    return _api.submitForEvaluation(current.submissionId!);
  }

  Future<SubmissionQuote> fetchQuote() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');
    return SubmissionQuote.fromJson(await _api.getQuote(current.submissionId!));
  }

  Future<Map<String, dynamic>> settleDeterminedResult() async {
    final current = state;
    if (current == null || current.submissionId == null) throw StateError('No active submission');

    final quote = await fetchQuote();
    var orderId = current.orderId;
    if (orderId == null || orderId.isEmpty) {
      final order = await _payment.createOrder(submissionId: current.submissionId!, quote: quote);
      orderId = order.orderId;
      state = (state ?? current).copyWith(orderId: orderId);
      if (order.checkoutUrl != null) {
        final launched = await _payment.launchCheckout(order);
        if (!launched) throw const SubmitApiException(502, 'Could not open secure checkout.');
        throw const SubmitApiException(202, 'Complete secure payment, return to PROVENANCE VERIFIED, then continue to reconcile settlement.');
      }
    }

    if (quote.paymentRequired) {
      final paymentStatus = await _payment.paymentStatus(orderId);
      if (paymentStatus != 'PAID') throw SubmitApiException(202, 'Payment status is $paymentStatus. Complete payment, then try again.');
      return _payment.bindSettlement(submissionId: current.submissionId!, orderId: orderId);
    }

    // T1 free order is bound server-side when it is created.
    return {'order_id': orderId, 'determined_tier': quote.tier, 'payment_status': 'FREE', 'settlement_bound': true};
  }

  @Deprecated('Use settleDeterminedResult after submitForEvaluation and canonical determination.')
  Future<Map<String, dynamic>> checkout({bool testMode = false}) => settleDeterminedResult();
}

final submitProvider = StateNotifierProvider<SubmitNotifier, SubmissionDraft?>((ref) {
  final api = ref.watch(submissionApiClientProvider);
  final payment = ref.watch(paymentCoordinatorProvider);
  return SubmitNotifier(api, payment);
});
