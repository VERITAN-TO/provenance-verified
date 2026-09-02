// Submit provider — manages wizard state and backend communication.
//
// MONEY_CONTROLS_TRUST = FALSE: Payment is a prerequisite to process,
// not a factor in trust determination.  The trust tier is determined
// exclusively by the backend after evidence review.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/submit_models.dart';
import '../../core/config/environment.dart';
import '../../core/auth/mobile_token_service.dart';

// ---------------------------------------------------------------------------
// Submission API client (scoped to submit/activity modules)
// ---------------------------------------------------------------------------

class SubmissionApiClient {
  final http.Client _client;
  final String _baseUrl;
  final MobileTokenService _tokenService;
  final bool _ownsTokenService;

  SubmissionApiClient({
    http.Client? client,
    String? baseUrl,
    MobileTokenService? tokenService,
  })  : _client           = client ?? http.Client(),
        _baseUrl          = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _ownsTokenService = tokenService == null,
        _tokenService     = tokenService ?? MobileTokenService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _authHeadersNoContent() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _refreshedHeaders() async {
    final token = await _tokenService.forceRefresh();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json;
    } catch (_) {
      return {'message': res.reasonPhrase ?? 'Unknown error'};
    }
  }

  // POST /api/v1/customer/submissions/start
  Future<Map<String, dynamic>> startSubmission({
    required String serviceTier,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/customer/submissions/start');
    final body = jsonEncode({'requested_service_tier': serviceTier});

    var res = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Start failed');
  }

  // POST /api/v1/customer/submissions/:id/asset-info
  Future<void> saveAssetInfo({
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/asset-info');
    final body = jsonEncode(payload);

    var res = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Asset info save failed');
  }

  // POST /api/v1/customer/submissions/:id/evidence (multipart)
  Future<void> uploadEvidence({
    required String submissionId,
    required String filePath,
    required String fileName,
    required String docType,
    required String token,
  }) async {
    final uri     = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/evidence');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['document_type']  = docType
      ..files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res      = await http.Response.fromStream(streamed);

    if (res.statusCode == 200 || res.statusCode == 201) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Evidence upload failed');
  }

  // POST /api/v1/customer/submissions/:id/declarations
  Future<void> saveDeclarations({
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/declarations');
    final body = jsonEncode(payload);

    var res = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200 || res.statusCode == 204) return;
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Declarations save failed');
  }

  // GET /api/v1/customer/submissions/:id/quote
  Future<Map<String, dynamic>> getQuote(String submissionId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/quote');

    var res = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      res = await _client
          .get(uri, headers: await _refreshedHeaders())
          .timeout(const Duration(seconds: 30));
    }

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Quote fetch failed');
  }

  // POST /api/v1/customer/submissions/:id/checkout
  Future<Map<String, dynamic>> checkout({
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final uri  = Uri.parse('$_baseUrl/api/v1/customer/submissions/$submissionId/checkout');
    final body = jsonEncode(payload);

    var res = await _client
        .post(uri, headers: await _authHeaders(), body: body)
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 401) {
      res = await _client
          .post(uri, headers: await _refreshedHeaders(), body: body)
          .timeout(const Duration(seconds: 60));
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = _parseError(res);
    throw SubmitApiException(res.statusCode, err['message'] as String? ?? 'Checkout failed');
  }

  /// Returns the current auth token (for multipart uploads that build their
  /// own request).
  Future<String> getToken() => _tokenService.getToken();

  void dispose() {
    _client.close();
    if (_ownsTokenService) _tokenService.dispose();
  }
}

class SubmitApiException implements Exception {
  final int statusCode;
  final String message;
  const SubmitApiException(this.statusCode, this.message);

  @override
  String toString() => 'SubmitApiException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Provider: shared SubmissionApiClient
// ---------------------------------------------------------------------------

final submissionApiClientProvider = Provider<SubmissionApiClient>((ref) {
  final c = SubmissionApiClient();
  ref.onDispose(c.dispose);
  return c;
});

// ---------------------------------------------------------------------------
// SubmitNotifier — wizard state machine
// ---------------------------------------------------------------------------

class SubmitNotifier extends StateNotifier<SubmissionDraft?> {
  final SubmissionApiClient _api;

  SubmitNotifier(this._api) : super(null);

  // ---- lifecycle ----

  void reset() => state = null;

  void beginNew() {
    state = const SubmissionDraft(step: 0);
  }

  // ---- Step 0: Service selection ----

  void selectTier(ServiceTier tier) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(selectedTier: tier);
  }

  // ---- Step 1: Asset info ----

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
    state = current.copyWith(
      photoPaths: current.photoPaths.where((p) => p != path).toList(),
    );
  }

  // ---- Step 2: Documents ----

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
    if (index >= 0 && index < docs.length) {
      docs[index] = docs[index].copyWith(uploaded: true);
    }
    state = current.copyWith(documents: docs);
  }

  void updateDocumentType(int index, EvidenceDocumentType docType) {
    final current = state ?? const SubmissionDraft(step: 0);
    final docs = List<EvidenceDocument>.from(current.documents);
    if (index >= 0 && index < docs.length) {
      docs[index] = docs[index].copyWith(docType: docType);
    }
    state = current.copyWith(documents: docs);
  }

  // ---- Step 3: Declarations ----

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

  // ---- Step navigation ----

  void goToStep(int step) {
    final current = state ?? const SubmissionDraft(step: 0);
    state = current.copyWith(step: step);
  }

  // ---- Backend calls ----

  /// Called when the user confirms service tier and moves to step 1.
  /// Starts the submission on the backend and stores the submissionId.
  Future<void> startSubmission() async {
    final current = state;
    if (current == null || current.selectedTier == null) {
      throw StateError('No tier selected');
    }

    final result = await _api.startSubmission(
      serviceTier: current.selectedTier!.apiValue,
    );

    state = current.copyWith(
      submissionId: result['submission_id'] as String?,
      orderId:      result['order_id'] as String?,
      step:         1,
    );
  }

  /// Saves asset info to backend.
  Future<void> saveAssetInfo() async {
    final current = state;
    if (current == null || current.submissionId == null) {
      throw StateError('No active submission');
    }

    final attrs = current.gemstoneAttributes;
    await _api.saveAssetInfo(
      submissionId: current.submissionId!,
      payload: {
        'asset_name': current.assetName,
        'asset_type': current.assetType,
        'gemstone_attributes': attrs.toJson(),
      },
    );
  }

  /// Uploads all pending (non-uploaded) evidence documents.
  Future<void> uploadPendingDocuments() async {
    final current = state;
    if (current == null || current.submissionId == null) {
      throw StateError('No active submission');
    }

    final token = await _api.getToken();
    for (int i = 0; i < current.documents.length; i++) {
      final doc = current.documents[i];
      if (!doc.uploaded) {
        await _api.uploadEvidence(
          submissionId: current.submissionId!,
          filePath:     doc.filePath,
          fileName:     doc.fileName,
          docType:      doc.docType.apiValue,
          token:        token,
        );
        markDocumentUploaded(i);
      }
    }
  }

  /// Saves declarations to backend.
  Future<void> saveDeclarations() async {
    final current = state;
    if (current == null || current.submissionId == null) {
      throw StateError('No active submission');
    }

    await _api.saveDeclarations(
      submissionId: current.submissionId!,
      payload: {
        'declared_accurate':          current.declaredAccurate,
        'declared_tier_may_differ':   current.declaredTierMayDiffer,
        'declared_terms_agreed':      current.declaredTermsAgreed,
      },
    );
  }

  /// Fetches the pricing quote from the backend.
  Future<SubmissionQuote> fetchQuote() async {
    final current = state;
    if (current == null || current.submissionId == null) {
      throw StateError('No active submission');
    }

    final json = await _api.getQuote(current.submissionId!);
    return SubmissionQuote.fromJson(json);
  }

  /// Initiates checkout. In QUAL test mode the caller passes
  /// test_mode: true so the backend uses a simulated payment flow.
  /// No real payment is processed here — the backend owns that.
  Future<Map<String, dynamic>> checkout({bool testMode = false}) async {
    final current = state;
    if (current == null || current.submissionId == null) {
      throw StateError('No active submission');
    }

    final payload = <String, dynamic>{
      if (testMode) 'test_mode': true,
    };

    final result = await _api.checkout(
      submissionId: current.submissionId!,
      payload: payload,
    );
    return result;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final submitProvider =
    StateNotifierProvider<SubmitNotifier, SubmissionDraft?>((ref) {
  final api = ref.watch(submissionApiClientProvider);
  return SubmitNotifier(api);
});
