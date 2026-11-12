/// Explicit build target. No historical host or credentials are bundled.
abstract final class ApiConfig {
  static const bool deviceLocationEnabled = bool.fromEnvironment('BEEF_ENABLE_DEVICE_LOCATION', defaultValue: false);
  static const String _configuredUrl = String.fromEnvironment('BEEF_API_BASE_URL');
  static String get baseUrl => _configuredUrl.replaceFirst(RegExp(r'/$'), '');
  static bool isValid(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty && !uri.hasQuery && !uri.hasFragment &&
      (uri.path.isEmpty || uri.path == '/');
  }
  static bool get isConfigured => isValid(baseUrl);
}
