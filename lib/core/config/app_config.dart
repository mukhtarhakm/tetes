abstract final class AppConfig {
  static const functionsBaseUrl =
      'https://osqznapcbeceaizpvccc.supabase.co/functions/v1';
  static const authRequestTimeout = Duration(seconds: 20);
  static const pendingRevokeRetryTimeout = Duration(seconds: 3);
}
