// M2: Real E2E qualification — all endpoints are REAL backend endpoints.
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52
// Credentials passed via --dart-define; NEVER hardcoded in source.

enum AppEnvironment { development, qualification, production }

class Env {
  static const String _env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  // M2: Real Vercel deployment URL for the PV authority API.
  static const String pvApiBaseUrl = String.fromEnvironment(
    'PV_API_BASE_URL',
    defaultValue: 'https://provenance-verified-private.vercel.app',
  );

  // M2: Bearer token for API key authentication (Authorization: Bearer <token>).
  // Required for trust:read, actionability:evaluate, reliance:create scopes.
  static const String pvApiKey = String.fromEnvironment(
    'PV_API_KEY',
    defaultValue: '',
  );

  // M2: Tenant ID associated with the API key.
  static const String pvTenantId = String.fromEnvironment(
    'PV_TENANT_ID',
    defaultValue: '',
  );

  // Supabase anon key — retained for potential Supabase realtime/auth use.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
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

  static bool get isProduction => current == AppEnvironment.production;
  static bool get isQualification => current == AppEnvironment.qualification;
  static bool get isDevelopment => current == AppEnvironment.development;

  // True if real backend credentials are available for integration tests.
  static bool get hasQualCredentials => pvApiKey.isNotEmpty && pvTenantId.isNotEmpty;
}
