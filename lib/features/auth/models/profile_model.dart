class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String role; // admin | staff | owner | superadmin
  final String? avatarUrl;

  const Profile({
    required this.id,
    this.email,
    this.fullName,
    this.role = 'staff',
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        email: json['email'] as String?,
        fullName: json['full_name'] as String?,
        role: (json['role'] as String?) ?? 'staff',
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'avatar_url': avatarUrl,
      };
}
