import '../models/grid_profile.dart';
import '../models/public_profile.dart';
import 'http_client.dart';

/// One page of the proximity grid.
class GridPage {
  const GridPage({
    required this.items,
    required this.hasMore,
    this.nextOffset,
  });

  final List<GridProfile> items;
  final bool hasMore;
  final int? nextOffset;

  factory GridPage.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['items'];
    final List<GridProfile> items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(GridProfile.fromJson)
            .toList()
        : const <GridProfile>[];
    final dynamic next = json['next_offset'];
    return GridPage(
      items: items,
      hasMore: json['has_more'] == true,
      nextOffset: next is int ? next : null,
    );
  }
}

/// Discovery endpoints consumed by the client. Mirrors the backend route files
/// `api/grid.ts` and `api/profile.$id.ts` exactly.
///
/// Supported grid query params (server-side): `limit` (1–100, default 50),
/// `offset` (>= 0), `radius_mi` (1–1000, default 50), `intent`
/// (`friends|chat|date|hookup`). Interest narrowing is client-side: the grid
/// returns a per-row `shared_interests` overlap count, which the
/// [DiscoveryController] uses to prioritise cuts with shared tastes.
class DiscoveryApi {
  DiscoveryApi(this._client);

  final ApiClient _client;

  /// GET /api/grid with the server-supported filters.
  Future<GridPage> grid({
    String? intent,
    int limit = 50,
    int offset = 0,
    double radiusMi = 50,
  }) async {
    final Map<String, String> params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'radius_mi': '$radiusMi',
    };
    if (intent != null && intent.isNotEmpty) {
      params['intent'] = intent;
    }
    final String query = params.entries
        .map((MapEntry<String, String> e) =>
            '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final Map<String, dynamic> data = await _client.get('/api/grid?$query');
    return GridPage.fromJson(data);
  }

  /// GET /api/profile/:id → `{ user: { … } }`. The backend strips birthdate
  /// and every location field; [PublicProfile] only exposes the safe subset.
  Future<PublicProfile> profile(String userId) async {
    final Map<String, dynamic> data =
        await _client.get('/api/profile/${Uri.encodeComponent(userId)}');
    return PublicProfile.fromJson(data['user'] as Map<String, dynamic>);
  }
}
