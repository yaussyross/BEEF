class RatingEligibility {
  const RatingEligibility({required this.eligible, this.myRating});

  final bool eligible;
  final int? myRating;

  factory RatingEligibility.fromJson(Map<String, dynamic> json) =>
      RatingEligibility(
        eligible: json['eligible'] == true,
        myRating: (json['my_rating'] as num?)?.toInt(),
      );
}
