import '../models/rating.dart';
import 'http_client.dart';

class RatingsApi {
  RatingsApi(this._client);
  final ApiClient _client;

  String _path(String userId) => '/api/ratings/${Uri.encodeComponent(userId)}';

  Future<RatingEligibility> eligibility(String userId) async =>
      RatingEligibility.fromJson(await _client.get(_path(userId)));

  Future<int> save(String userId, int stars) async {
    if (stars < 1 || stars > 5) throw ArgumentError.value(stars, 'stars');
    final data = await _client.post(_path(userId), body: {'stars': stars});
    return (data['rating'] as Map<String, dynamic>)['stars'] as int;
  }
}
