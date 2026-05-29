class UnlinkedLineUser {
  final String lineUserId;
  final String? displayName;
  final String? pictureUrl;
  final String createdAt;

  const UnlinkedLineUser({
    required this.lineUserId,
    this.displayName,
    this.pictureUrl,
    required this.createdAt,
  });

  factory UnlinkedLineUser.fromJson(Map<String, dynamic> json) {
    return UnlinkedLineUser(
      lineUserId: json['line_user_id'] as String,
      displayName: json['display_name'] as String?,
      pictureUrl: json['picture_url'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
