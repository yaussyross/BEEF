import 'interest.dart';

/// Null-safe decoding helpers shared by the profile models. JSON arrays can be
/// absent or `null` in some responses (e.g. before a profile is edited), so
/// every list field decodes defensively to an empty list.

List<String> jsonStringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const <String>[];
}

List<Interest> jsonInterestList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(Interest.fromJson)
        .toList();
  }
  return const <Interest>[];
}
