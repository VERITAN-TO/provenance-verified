class PvConstants {
  static const Duration cacheStaleThreshold = Duration(hours: 24);
  static const Duration cacheOfflineTtl = Duration(days: 7);
  static const Duration networkConnectTimeout = Duration(seconds: 10);
  static const Duration networkReceiveTimeout = Duration(seconds: 15);
  static const Duration networkSendTimeout = Duration(seconds: 10);

  // M1 Security Law: actionability must never be cached for reliance.
  static const bool actionabilityCacheForReliance = false;

  static const String mta1ContractSha =
      'c446198e5ef4eb96cfe84c8c280a0ba94e4eac52';

  static final RegExp publicIdPattern =
      RegExp(r'^(PV|DET(-V\d+)?)-[A-Z0-9]+(-[A-Z0-9]+)+$');

  static final RegExp digestPattern =
      RegExp(r'^sha256:[0-9a-f]{64}$');
}
