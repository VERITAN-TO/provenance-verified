enum AppEnvironment { development, qualification, production }

class Env {
  static const String _env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gz3l3arol.supabase.co/functions/v1',
  );
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
}
