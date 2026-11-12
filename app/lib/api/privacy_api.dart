import 'http_client.dart';

/// Only privacy preferences are retained from the owner's full profile response.
class PrivacySettings {
  const PrivacySettings({required this.mode, required this.hideDistance});
  final String mode;
  final bool hideDistance;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    final mode = json['coarse_location'];
    final hide = json['hide_distance'];
    if (mode is! String || !['city', 'region', 'exact'].contains(mode) || hide is! bool) {
      throw const FormatException('Invalid privacy preferences');
    }
    return PrivacySettings(mode: mode, hideDistance: hide);
  }
}

class PrivacyApi {
  PrivacyApi(this._client);
  final ApiClient _client;

  Future<PrivacySettings> load() async {
    final data = await _client.get('/api/profile');
    return PrivacySettings.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<PrivacySettings> save(String mode, bool hideDistance) async {
    if (!['city', 'region', 'exact'].contains(mode)) throw ArgumentError.value(mode);
    final data = await _client.put('/api/profile', body: {
      'coarse_location': mode,
      'hide_distance': hideDistance,
    });
    return PrivacySettings.fromJson(data['user'] as Map<String, dynamic>);
  }
}
