import 'json_utils.dart';

/// One row of the proximity grid (`GET /api/grid` → `items[]`).
///
/// The server returns a privacy-safe projection only: a bucketed `distance`
/// label (e.g. "<1 mi", "1–5 mi", "nearby", or a rounded "2.3 mi" when the
/// remote opted into exact mode) — never raw coordinates — plus a
/// `shared_interests` overlap count. The client renders these verbatim and
/// must never attempt to derive a precise location from them.
class GridProfile {
  const GridProfile({
    required this.userId,
    this.displayName,
    this.bio,
    this.intentTags = const [],
    this.photoVerificationStatus,
    required this.distance,
    this.sharedInterests = 0,
    this.lastActiveAt,
  });

  final String userId;
  final String? displayName;
  final String? bio;

  /// Wire-format intent tags (`friends`, `chat`, `date`, `hookup`).
  final List<String> intentTags;

  /// One of `unverified` | `pending` | `verified` | `rejected`.
  final String? photoVerificationStatus;

  /// Server-computed, privacy-safe distance label. Render verbatim.
  final String distance;

  /// Count of interests shared with the viewer (drives interest-led sorting).
  final int sharedInterests;

  final String? lastActiveAt;

  bool get isVerified => photoVerificationStatus == 'verified';

  /// "nearby" means the remote hid their distance — display it, don't explain
  /// it away or try to resolve it.
  bool get hidesDistance => distance == 'nearby';

  String get displayLabel {
    final String? name = displayName;
    if (name != null && name.isNotEmpty) return name;
    return 'Fresh cut';
  }

  factory GridProfile.fromJson(Map<String, dynamic> json) => GridProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        bio: json['bio'] as String?,
        intentTags: jsonStringList(json['intent_tags']),
        photoVerificationStatus:
            json['photo_verification_status'] as String?,
        distance: json['distance'] as String? ?? 'nearby',
        sharedInterests: _asInt(json['shared_interests']),
        lastActiveAt: json['last_active_at'] as String?,
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
