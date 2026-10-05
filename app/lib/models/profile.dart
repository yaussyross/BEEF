import 'interest.dart';
import 'json_utils.dart';

/// The authenticated user's own profile.
///
/// `/api/me` returns the non-sensitive subset (no birthdate, no location);
/// `/api/profile` returns the full view — including the caller's OWN birthdate,
/// which must NEVER be rendered for or shared with another user. This single
/// model covers both shapes: absent fields simply stay `null`.
class Profile {
  const Profile({
    required this.id,
    this.email,
    this.status,
    this.displayName,
    this.bio,
    this.intentTags = const [],
    this.photoVerificationStatus,
    this.hideDistance = false,
    this.coarseLocation,
    this.birthdate,
    this.interests = const [],
  });

  final String id;
  final String? email;
  final String? status;
  final String? displayName;
  final String? bio;

  /// Wire-format intent tags (`friends`, `chat`, `date`, `hookup`).
  final List<String> intentTags;

  final String? photoVerificationStatus;
  final bool hideDistance;

  /// One of `exact` | `city` | `region`. Privacy toggle, not a location.
  final String? coarseLocation;

  /// OWN profile only. The backend strips this from every public/other-user
  /// view; the client must never display it to anyone but the owner.
  final String? birthdate;

  final List<Interest> interests;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        email: json['email'] as String?,
        status: json['status'] as String?,
        displayName: json['display_name'] as String?,
        bio: json['bio'] as String?,
        intentTags: jsonStringList(json['intent_tags']),
        photoVerificationStatus: json['photo_verification_status'] as String?,
        hideDistance: json['hide_distance'] == true,
        coarseLocation: json['coarse_location'] as String?,
        birthdate: json['birthdate'] as String?,
        interests: jsonInterestList(json['interests']),
      );
}
