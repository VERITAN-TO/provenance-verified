// Canonical payment/order coordinator for the customer submission flow.
//
// MONEY_CONTROLS_TRUST = FALSE.
// This client never sends an amount or Stripe price ID. The server owns price,
// order state and Stripe session creation. Final intake requires a canonical
// order whose payment state is FREE or PAID.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/config/environment.dart';
import '../models/submit_models.dart';
import 'submit_provider.dart' show SubmitApiException;

class CanonicalOrderResult {
  final String orderId;
  final String? checkoutSessionId;
  final Uri? checkoutUrl;
  final String paymentStatus;

  const CanonicalOrderResult({
    required this.orderId,
    this.checkoutSessionId,
    this.checkoutUrl,
    required this.paymentStatus,
  });
}

class PaymentCoordinator {
  final Ref _ref;
  final http.Client _client;
  final String _baseUrl;

  PaymentCoordinator(this._ref, {http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.pvApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  Future<String> _token({bool forceRefresh = false}) async {
    if (forceRefresh || _ref.read(authProvider)?.isExpired == true) {
      await _ref.read(authProvider.notifier).refresh();
    }
    final token = _ref.read(authProvider)?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    return token;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    Future<http.Response> send(String token) => _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    var res = await send(await _token());
    if (res.statusCode == 401) res = await send(await _token(forceRefresh: true));
    return res;
  }

  Future<http.Response> _get(String path) async {
    Future<http.Response> send(String token) => _client
        .get(Uri.parse('$_baseUrl$path'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    var res = await send(await _token());
    if (res.statusCode == 401) res = await send(await _token(forceRefresh: true));
    return res;
  }

  Map<String, dynamic> _json(http.Response res) {
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Never _throw(http.Response res, String fallback) {
    String message = fallback;
    try {
      final j = _json(res);
      final error = j['error'];
      if (error is Map<String, dynamic>) {
        message = error['message']?.toString() ?? error['code']?.toString() ?? fallback;
      }
    } catch (_) {}
    throw SubmitApiException(res.statusCode, message);
  }

  Future<CanonicalOrderResult> createOrder({
    required String submissionId,
    required SubmissionQuote quote,
  }) async {
    if (!quote.paymentRequired) {
      final res = await _post('/api/v1/payments/orders', {'sessionId': submissionId});
      if (res.statusCode != 200 && res.statusCode != 201) _throw(res, 'Could not create free order');
      final data = (_json(res)['data'] as Map<String, dynamic>?) ?? const {};
      final orderId = data['orderId']?.toString() ?? '';
      if (orderId.isEmpty) throw const SubmitApiException(502, 'Free order response did not include orderId');
      return CanonicalOrderResult(
        orderId: orderId,
        paymentStatus: data['paymentStatus']?.toString() ?? 'FREE',
      );
    }

    if (quote.csaVersion.isEmpty || quote.serviceCode.isEmpty) {
      throw const SubmitApiException(422, 'Canonical quote is missing service or CSA authority');
    }
    final res = await _post('/api/v1/payments/checkout', {
      'serviceCode': quote.serviceCode,
      'csaVersion': quote.csaVersion,
    });
    if (res.statusCode != 200 && res.statusCode != 201) _throw(res, 'Could not create checkout');
    final data = (_json(res)['data'] as Map<String, dynamic>?) ?? const {};
    final orderId = data['orderId']?.toString() ?? '';
    final url = data['checkoutUrl']?.toString() ?? '';
    if (orderId.isEmpty || url.isEmpty) throw const SubmitApiException(502, 'Checkout response is incomplete');
    return CanonicalOrderResult(
      orderId: orderId,
      checkoutSessionId: data['checkoutSessionId']?.toString(),
      checkoutUrl: Uri.tryParse(url),
      paymentStatus: 'PENDING',
    );
  }

  Future<bool> launchCheckout(CanonicalOrderResult order) async {
    final uri = order.checkoutUrl;
    if (uri == null) return true;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<String> paymentStatus(String orderId) async {
    final res = await _get('/api/v1/payments/orders?limit=50');
    if (res.statusCode != 200) _throw(res, 'Could not read order status');
    final data = (_json(res)['data'] as Map<String, dynamic>?) ?? const {};
    final orders = data['orders'];
    if (orders is! List) throw const SubmitApiException(502, 'Order list response is invalid');
    for (final item in orders.whereType<Map<String, dynamic>>()) {
      if (item['orderId']?.toString() == orderId) {
        return item['paymentStatus']?.toString() ?? 'UNKNOWN';
      }
    }
    throw const SubmitApiException(404, 'Order not found');
  }

  Future<Map<String, dynamic>> finalize({
    required String submissionId,
    required String orderId,
  }) async {
    final res = await _post(
      '/api/v1/customer/submissions/${Uri.encodeComponent(submissionId)}/checkout',
      {'order_id': orderId},
    );
    if (res.statusCode != 200 && res.statusCode != 201) _throw(res, 'Could not finalize submission');
    final json = _json(res);
    return (json['data'] as Map<String, dynamic>?) ?? json;
  }

  void dispose() => _client.close();
}

final paymentCoordinatorProvider = Provider<PaymentCoordinator>((ref) {
  final coordinator = PaymentCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
