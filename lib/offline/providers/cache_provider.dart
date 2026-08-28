import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../offline_state.dart';
import '../../core/config/constants.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

class CacheNotifier extends AsyncNotifier<Map<String, CachedRecord>> {
  static const _prefix = 'pv_cache_';

  @override
  Future<Map<String, CachedRecord>> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final map = <String, CachedRecord>{};
    for (final key in keys) {
      try {
        final json = prefs.getString(key);
        if (json != null) {
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          final cachedAt = DateTime.parse(decoded['cached_at'] as String);
          final age = DateTime.now().toUtc().difference(cachedAt);
          final state = age > PvConstants.cacheStaleThreshold
              ? CacheState.stale
              : CacheState.fresh;
          map[decoded['public_id'] as String] = CachedRecord(
            publicId: decoded['public_id'] as String,
            data: decoded['data'] as Map<String, dynamic>,
            cachedAt: cachedAt,
            state: state,
          );
        }
      } catch (_) {}
    }
    return map;
  }

  Future<void> put(String publicId, Map<String, dynamic> data) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final payload = jsonEncode({
      'public_id': publicId,
      'data': data,
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    });
    await prefs.setString('$_prefix$publicId', payload);
    ref.invalidateSelf();
  }

  Future<void> evict(String publicId) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.remove('$_prefix$publicId');
    ref.invalidateSelf();
  }
}

final cacheProvider = AsyncNotifierProvider<CacheNotifier, Map<String, CachedRecord>>(
  CacheNotifier.new,
);
