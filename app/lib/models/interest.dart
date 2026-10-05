/// A discoverable interest, as returned in profile responses
/// (`{ slug, label }`).
class Interest {
  const Interest({required this.slug, required this.label});

  final String slug;
  final String label;

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
        slug: json['slug'] as String,
        label: json['label'] as String,
      );
}
