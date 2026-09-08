/// Compile-time API configuration.
///
/// The backend API is served by the same host as the BEEF site (under
/// `src/routes/api/*`). Override the base URL per environment at build time:
///
///   flutter build ... --dart-define=BEEF_API_BASE_URL=https://your-host
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'BEEF_API_BASE_URL',
    defaultValue: 'https://6a67ca40db0e489b44ec1ac481ec6ea6.ctonew.app',
  );
}
