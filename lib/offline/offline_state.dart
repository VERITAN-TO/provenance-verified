enum CacheState { fresh, stale, expired, missing }

class CachedRecord {
  final String publicId;
  final Map<String, dynamic> data;
  final DateTime cachedAt;
  final CacheState state;

  const CachedRecord({
    required this.publicId,
    required this.data,
    required this.cachedAt,
    this.state = CacheState.fresh,
  });
}
