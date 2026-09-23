// SAS1 Production: No static API key embedded.
// Mobile tokens are issued dynamically via POST /api/v1/mobile/token.
// PV_TENANT_ID is a public identifier — not a secret.
// MTA2_CONTRACT: STATIC_PRODUCTION_API_KEY_IN_MOBILE = ZERO

enum AppEnvironment { development, qualification, production }

class Env {
  static const String _env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  static const String pvApiBaseUrl = String.fromEnvironment(
    'PV_API_BASE_URL',
    defaultValue: 'https://provenance-verified-private.vercel.app',
  );

  // Public tenant identifier — NOT a secret. Enrolled in pv_mobile_consumer_tenants.
  static const String pvTenantId = String.fromEnvironment(
    'PV_TENANT_ID',
    defaultValue: '',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '3.0.0',
  );

  static AppEnvironment get current {
    switch (_env) {
      case 'production':
        return AppEnvironment.production;
      case 'qualification':
        return AppEnvironment.qualification;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isProduction    => current == AppEnvironment.production;
  static bool get isQualification => current == AppEnvironment.qualification;
  static bool get isDevelopment   => current == AppEnvironment.development;

  static bool get isConfigured => pvTenantId.isNotEmpty;

  // CI/test platform override — allows non-UUID fixture tenant_ids when A-side
  // accepts platform='test'. Set via --dart-define=PV_MOBILE_PLATFORM=test in CI.
  // Production runtime guard on the server side blocks test platform in production.
  static const String mobilePlatform = String.fromEnvironment(
    'PV_MOBILE_PLATFORM',
    defaultValue: '',
  );

  // CI/qual device UUID override — set via --dart-define=PV_QUAL_DEVICE_ID=<uuid> in CI.
  // When non-empty, MobileTokenService uses this as device_id for bootstrap,
  // bypassing secure-storage lookup. Semantically distinct from PV_QUAL_SUBJECT_ID
  // (determination subject/public_id). Production: empty — device ID managed by
  // MobileTokenService secure storage.
  static const String qualDeviceId = String.fromEnvironment(
    'PV_QUAL_DEVICE_ID',
    defaultValue: '',
  );

  // Supabase — customer auth only. Not a secret (anon key is public by design).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
