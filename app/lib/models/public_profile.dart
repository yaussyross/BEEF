import 'interest.dart';
import 'json_utils.dart';

/// A sanitised PUBLIC view of another user (from `/api/profile/:id`).
///
/// The backend guarantees no birthdate and no location are ever present here —
/// only `is_adult` + `age_bucket`. The client must never attempt to display a
/// remote user's raw birthdate or precise location (the API does not even
/// return them).
class PublicProfile {
  const PublicProfile({
    required this.id,
    this.displayName,
    this.bio,
    this.intentTags = const [],
    this.photoVerificationStatus,
    this.isAdult = false,
    this.ageBucket,
    this.interests = const [],
  });

  final String id;
  final String? displayName;
  final String? bio;
  final List<String> intentTags;
  final String? photoVerificationStatus;
  final bool isAdult;
  final String? ageBucket;
  final List<Interest> interests;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        bio: json['bio'] as String?,
        intentTags: jsonStringList(json['intent_tags']),
        photoVerificationStatus: json['photo_verification_status'] as String?,
        isAdult: json['is_adult'] == true,
        ageBucket: json['age_bucket'] as String?,
        interests: jsonInterestList(json['interests']),
      );
}
