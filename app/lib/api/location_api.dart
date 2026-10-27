import 'http_client.dart';

class LocationApi {
  LocationApi(this._client);
  final ApiClient _client;
  Future<void> update(double latitude, double longitude) async {
    final data = await _client.post('/api/location', body: {'lat': latitude, 'lng': longitude});
    if (data['ok'] != true) throw const FormatException('Location update was not confirmed');
  }
}
