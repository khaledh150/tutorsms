class AppUser {
  final String id;
  final String? email;
  final String role; // superadmin | owner | admin | staff
  final String? schoolId;
  final String? fullName;
  final String? username;

  const AppUser({
    required this.id,
    this.email,
    this.role = 'staff',
    this.schoolId,
    this.fullName,
    this.username,
  });

  bool get isSuperAdmin => role == 'superadmin';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner' || role == 'superadmin';
  bool get isStaff => role == 'staff';

  factory AppUser.fromProfile(String id, String? email, Map<String, dynamic>? profile) {
    return AppUser(
      id: id,
      email: email,
      role: (profile?['role'] as String?) ?? 'staff',
      schoolId: profile?['school_id'] as String?,
      fullName: profile?['full_name'] as String?,
      username: profile?['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'school_id': schoolId,
        'full_name': fullName,
        'username': username,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String?,
        role: (json['role'] as String?) ?? 'staff',
        schoolId: json['school_id'] as String?,
        fullName: json['full_name'] as String?,
        username: json['username'] as String?,
      );
}
