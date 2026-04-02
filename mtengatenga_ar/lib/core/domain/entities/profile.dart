class Profile {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? '',
        email: map['email'] as String,
        avatarUrl: map['avatar_url'] as String?,
      );
}
