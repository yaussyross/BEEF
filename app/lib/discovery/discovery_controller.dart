import 'package:flutter/foundation.dart';

import '../api/discovery_api.dart';
import '../models/grid_profile.dart';
import '../models/intent_tag.dart';

/// The 16 seeded interest slugs (migration `0006_seed_interests.sql`) backing
/// interest-led discovery. Slugs are the wire format; labels are display-only.
/// "The Menu" — the interest-led lane of the grid.
abstract final class DiscoveryInterests {
  static const List<InterestOption> all = <InterestOption>[
    InterestOption('gym-bros', 'Gym bros'),
    InterestOption('coffee-dates', 'Coffee dates'),
    InterestOption('hiking', 'Hiking'),
    InterestOption('brunch', 'Brunch'),
    InterestOption('film-buffs', 'Film buffs'),
    InterestOption('live-music', 'Live music'),
    InterestOption('gamers', 'Gamers'),
    InterestOption('art-galleries', 'Art galleries'),
    InterestOption('drag-shows', 'Drag shows'),
    InterestOption('dogs', 'Dog people'),
    InterestOption('travel', 'Travel'),
    InterestOption('foodies', 'Foodies'),
    InterestOption('book-club', 'Book club'),
    InterestOption('running', 'Running'),
    InterestOption('climbing', 'Climbing'),
    InterestOption('photography', 'Photography'),
  ];

  static String labelFor(String slug) {
    for (final InterestOption option in all) {
      if (option.slug == slug) return option.label;
    }
    return slug;
  }
}

class InterestOption {
  const InterestOption(this.slug, this.label);

  final String slug;
  final String label;
}

enum DiscoveryStatus { idle, loading, loaded, empty, error }

/// Owns grid state for the proximity grid screen: server-side `intent`
/// filtering (incl. the "A Plate of Mates" friends-only lane), pull-to-refresh,
/// pagination, and client-side interest narrowing ("The Menu").
///
/// Selected interest slugs filter on the server. A request generation prevents
/// stale responses from replacing a newer selection.
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({required this.api});

  final DiscoveryApi api;

  int _generation = 0;
  bool _disposed = false;

  @override
  void dispose() { _disposed = true; _generation++; api.close(); super.dispose(); }

  DiscoveryStatus _status = DiscoveryStatus.idle;
  List<GridProfile> _items = const <GridProfile>[];
  String? _error;
  bool _hasMore = false;
  int? _nextOffset;
  bool _loadingMore = false;

  /// Server-side intent filter (`friends|chat|date|hookup`), or null for all.
  String? _intent;

  /// "A Plate of Mates" — the friends-only lane. Backed by `intent=friends`;
  /// toggling on sets the intent filter, toggling off clears it.
  bool _matesOnly = false;

  /// Selected interest slugs for "The Menu" interest-led lane. Client-side
  /// re-sort only (see class docs); empty means no narrowing.
  Set<String> _selectedInterests = <String>{};

  DiscoveryStatus get status => _status;
  List<GridProfile> get items => List<GridProfile>.unmodifiable(_items);
  List<GridProfile> get rawItems => List<GridProfile>.unmodifiable(_items);
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get intent => _intent;
  bool get matesOnly => _matesOnly;
  Set<String> get selectedInterests =>
      Set<String>.unmodifiable(_selectedInterests);
  bool get hasActiveFilters =>
      _intent != null || _selectedInterests.isNotEmpty;

  List<IntentTag?> get intentOptions =>
      <IntentTag?>[null, ...IntentTag.values];

  /// Select an intent tag filter (null clears). Any non-friends tag exits the
  /// mates-only lane; the friends chip leaves the toggle as-is.
  Future<void> setIntent(IntentTag? tag) async {
    _intent = tag?.value;
    if (tag != IntentTag.friends) _matesOnly = false;
    await refresh();
  }

  /// Toggle "A Plate of Mates" — friends-only lane (`intent=friends`).
  Future<void> setMatesOnly(bool value) async {
    _matesOnly = value;
    _intent = value ? IntentTag.friends.value : null;
    await refresh();
  }

  /// Toggle an interest chip and fetch matching profiles.
  Future<void> toggleInterest(String slug) async {
    final Set<String> next = Set<String>.from(_selectedInterests);
    if (next.contains(slug)) {
      next.remove(slug);
    } else {
      next.add(slug);
    }
    _selectedInterests = next;
    await refresh();
  }

  Future<void> clearInterestFilter() async {
    if (_selectedInterests.isEmpty) return;
    _selectedInterests = <String>{};
    await refresh();
  }

  Future<void> clearAllFilters() async {
    _intent = null;
    _matesOnly = false;
    _selectedInterests = <String>{};
    await refresh();
  }

  /// First page (also used for pull-to-refresh).
  Future<void> refresh() async {
    final generation = ++_generation;
    _items = []; _hasMore = false; _nextOffset = null;
    _status = _items.isEmpty ? DiscoveryStatus.loading : _status;
    _error = null;
    notifyListeners();
    try {
      final GridPage page = await api.grid(intent: _intent, interests: _selectedInterests);
      if (_disposed || generation != _generation) return;
      _items = page.items;
      _hasMore = page.hasMore;
      _nextOffset = page.nextOffset;
      _status = _items.isEmpty ? DiscoveryStatus.empty : DiscoveryStatus.loaded;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = _friendlyError(e);
      _status = _items.isEmpty ? DiscoveryStatus.error : DiscoveryStatus.loaded;
    }
    notifyListeners();
  }

  /// Next page via the server's `next_offset` cursor.
  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _nextOffset == null) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final GridPage page =
          await api.grid(intent: _intent, interests: _selectedInterests, offset: _nextOffset!);
      if (_disposed || generation != _generation) return;
      _items = <GridProfile>[..._items, ...page.items];
      _hasMore = page.hasMore;
      _nextOffset = page.nextOffset;
      if (_status == DiscoveryStatus.empty && _items.isNotEmpty) {
        _status = DiscoveryStatus.loaded;
      }
    } catch (_) {
      // Keep the loaded rows; a retry happens on next scroll or refresh.
    } finally {
      _loadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  static String _friendlyError(Object e) => e.toString();
}
