import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

// Shell
import 'main_shell.dart';

// Branch 0 — Home
import '../../home/screens/home_screen.dart';

// Branch 1 — Verify (public, no auth required)
import '../../scanner/screens/scanner_screen.dart';
import '../../scanner/screens/manual_entry_screen.dart';
import '../../trust/screens/trust_result_screen.dart';
import '../../trust/screens/why_this_tier_screen.dart';
import '../../trust/screens/why_not_higher_screen.dart';
import '../../trust/screens/authority_screen.dart';
import '../../actionability/screens/actionability_screen.dart';
import '../../reliance/screens/reliance_screen.dart';

// Branch 2 — My PV (auth required)
import '../../my_pv/screens/my_pv_screen.dart';
import '../../my_pv/screens/asset_detail_screen.dart';
import '../../reliance/screens/receipt_list_screen.dart';
import '../../reliance/screens/receipt_detail_screen.dart';

// Branch 3 — Submit (auth required)
import '../../submit/screens/submit_screen.dart';

// Branch 4 — Activity (auth required)
import '../../activity/screens/activity_screen.dart';

// Auth screens (no auth required)
import '../../auth/screens/sign_in_screen.dart';
import '../../auth/screens/sign_up_screen.dart';

// ---------------------------------------------------------------------------
// Auth check
// ---------------------------------------------------------------------------

const String _sessionKey = 'pv_customer_session';
const _storage = FlutterSecureStorage();

/// Paths that require the user to be signed in.
const _protectedPrefixes = ['/my-pv', '/submit', '/activity'];

Future<bool> _isAuthenticated() async {
  try {
    final session = await _storage.read(key: _sessionKey);
    return session != null && session.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final GoRouter appRouter = GoRouter(
  initialLocation: '/verify',

  // ------------------------------------------------------------------
  // Auth redirect: guard /my-pv, /submit, /activity.
  // /verify/:id and all sub-routes are always public.
  // ------------------------------------------------------------------
  redirect: (BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;
    final isProtected = _protectedPrefixes.any(location.startsWith);
    if (!isProtected) return null;

    final authenticated = await _isAuthenticated();
    if (authenticated) return null;

    final from = Uri.encodeComponent(state.uri.toString());
    return '/sign-in?from=$from';
  },

  routes: [
    // ----------------------------------------------------------------
    // Root shell — 5-tab bottom navigation
    // ----------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // ---- Branch 0: Home ----------------------------------------
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // ---- Branch 1: Verify (all public) -------------------------
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/verify',
              name: 'verify-tab',
              builder: (context, state) => const ScannerScreen(),
              routes: [
                GoRoute(
                  path: 'scan',
                  name: 'verify-scan',
                  builder: (context, state) => const ScannerScreen(),
                ),
                GoRoute(
                  path: 'manual',
                  name: 'verify-manual',
                  builder: (context, state) => const ManualEntryScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'trust-result',
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
              ],
            ),
          ],
        ),

        // ---- Branch 2: My PV (auth required) -----------------------
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-pv',
              name: 'my-pv',
              builder: (context, state) => const MyPvScreen(),
              routes: [
                GoRoute(
                  path: 'asset/:assetId',
                  name: 'asset-detail',
                  builder: (context, state) {
                    final assetId = state.pathParameters['assetId'] ?? '';
                    return AssetDetailScreen(assetId: assetId);
                  },
                ),
                GoRoute(
                  path: 'receipts',
                  name: 'receipt-list',
                  builder: (context, state) => const ReceiptListScreen(),
                  routes: [
                    GoRoute(
                      path: ':receiptId',
                      name: 'receipt-detail',
                      builder: (context, state) {
                        final receiptId =
                            state.pathParameters['receiptId'] ?? '';
                        return ReceiptDetailScreen(receiptId: receiptId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // ---- Branch 3: Submit (auth required) ----------------------
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/submit',
              name: 'submit',
              builder: (context, state) => const SubmitScreen(),
            ),
          ],
        ),

        // ---- Branch 4: Activity (auth required) --------------------
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              name: 'activity',
              builder: (context, state) => const ActivityScreen(),
            ),
          ],
        ),
      ],
    ),

    // ------------------------------------------------------------------
    // Auth screens — outside the shell, no auth required
    // ------------------------------------------------------------------
    GoRoute(
      path: '/sign-in',
      name: 'sign-in',
      builder: (context, state) {
        final from = state.uri.queryParameters['from'];
        return SignInScreen(redirectPath: from);
      },
    ),
    GoRoute(
      path: '/sign-up',
      name: 'sign-up',
      builder: (context, state) => const SignUpScreen(),
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  ),
);
