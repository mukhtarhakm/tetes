abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supabaseRestBaseUrl = '$supabaseUrl/rest/v1';
  static const functionsBaseUrl =
      'https://osqznapcbeceaizpvccc.supabase.co/functions/v1';
  static const fxBaseUrl = 'https://api.frankfurter.dev/v1';
  static const authRequestTimeout = Duration(seconds: 20);
  static const fxRequestTimeout = Duration(seconds: 12);
  static const fxInputDebounce = Duration(milliseconds: 500);
  static const pendingRevokeRetryTimeout = Duration(seconds: 3);
}
