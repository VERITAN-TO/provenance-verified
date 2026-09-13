import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_models.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Shared AuthService instance
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<CustomerSession?> {
  final AuthService _service;

  AuthNotifier(this._service) : super(null) {
    _loadStoredSession();
  }

  Future<void> _loadStoredSession() async {
    try {
      final session = await _service.getStoredSession();
      if (mounted) state = session;
    } catch (_) {
      // No stored session — remain unauthenticated.
    }
  }

  bool get isAuthenticated => state != null && !(state!.isExpired);

  Future<void> signIn(String email, String password) async {
    final session = await _service.signIn(email, password);
    state = session;
  }

  Future<void> signUp(
      String email, String password, String displayName) async {
    final session = await _service.signUp(email, password, displayName);
    state = session;
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = null;
  }

  /// Manually trigger a token refresh and update state.
  Future<void> refresh() async {
    final session = await _service.refreshSession();
    state = session;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authProvider =
    StateNotifierProvider<AuthNotifier, CustomerSession?>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

/// Convenience read-only provider — returns the current session or null.
final currentUserProvider = Provider<CustomerSession?>((ref) {
  return ref.watch(authProvider);
});

/// True when there is a valid, non-expired session.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(authProvider);
  return session != null && !session.isExpired;
});
