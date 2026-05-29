class LineConnection {
  final String id;
  final String studentId;
  final String lineUserId;
  final String? displayName;
  final String? pictureUrl;

  const LineConnection({
    required this.id,
    required this.studentId,
    required this.lineUserId,
    this.displayName,
    this.pictureUrl,
  });

  factory LineConnection.fromJson(Map<String, dynamic> json) {
    return LineConnection(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      lineUserId: json['line_user_id'] as String,
      displayName: json['display_name'] as String?,
      pictureUrl: json['picture_url'] as String?,
    );
  }
}
