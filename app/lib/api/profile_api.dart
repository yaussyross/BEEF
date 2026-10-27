import 'http_client.dart';
import '../models/profile.dart';

class ProfileApi {
  ProfileApi(this._client);
  final ApiClient _client;
  Future<Profile> load() async {
    final data = await _client.get('/api/profile');
    return Profile.fromJson(data['user'] as Map<String, dynamic>);
  }
  Future<void> save(String name, String bio, Set<String> tags, Set<String> interests) async {
    final data = await _client.put('/api/profile', body: {
      'display_name': name.trim(), 'bio': bio.trim(),
      'intent_tags': tags.toList(), 'interests': interests.toList(),
    });
    if (data['user'] is! Map || data['user']['id'] is! String) {
      throw const FormatException('Profile save was not confirmed');
    }
  }
}
