import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../../scanner/screens/manual_entry_screen.dart';
import '../../trust/screens/trust_result_screen.dart';
import '../../trust/screens/why_this_tier_screen.dart';
import '../../trust/screens/why_not_higher_screen.dart';
import '../../trust/screens/authority_screen.dart';
import '../../actionability/screens/actionability_screen.dart';
import '../../reliance/screens/reliance_screen.dart';
import '../../reliance/screens/receipt_list_screen.dart';
import '../../reliance/screens/receipt_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/scan',
  routes: [
    GoRoute(
      path: '/scan',
      name: 'scan',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/manual',
      name: 'manual',
      builder: (context, state) => const ManualEntryScreen(),
    ),
    GoRoute(
      path: '/verify/:id',
      name: 'verify',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return TrustResultScreen(publicId: id);
      },
      routes: [
        GoRoute(
          path: 'why-this-tier',
          name: 'why-this-tier',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WhyThisTierScreen(publicId: id);
          },
        ),
        GoRoute(
          path: 'why-not-higher',
          name: 'why-not-higher',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WhyNotHigherScreen(publicId: id);
          },
        ),
        GoRoute(
          path: 'authority',
          name: 'authority',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AuthorityScreen(publicId: id);
          },
        ),
        GoRoute(
          path: 'actionability',
          name: 'actionability',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ActionabilityScreen(publicId: id);
          },
        ),
        GoRoute(
          path: 'reliance',
          name: 'reliance',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return RelianceScreen(publicId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/receipts',
      name: 'receipts',
      builder: (context, state) => const ReceiptListScreen(),
      routes: [
        GoRoute(
          path: ':receiptId',
          name: 'receipt-detail',
          builder: (context, state) {
            final receiptId = state.pathParameters['receiptId'] ?? '';
            return ReceiptDetailScreen(receiptId: receiptId);
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Not found: ${state.uri}'),
    ),
  ),
);
