/// Minimal authenticated user, as returned by `/api/register` and `/api/login`
/// (`{ id, email }`). The backend deliberately never includes the birthdate
/// here or in any token payload.
class User {
  const User({required this.id, required this.email});

  final String id;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
      );
}
