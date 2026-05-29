class ExpectedStudent {
  final String enrollmentId;
  final String studentId;
  final String courseId;
  final Map<String, List<String>> schedule;
  final int purchasedHours;
  final String firstName;
  final String lastName;
  final String? nickName;
  final String? qrCodeUrl;
  final String courseName;
  final double hoursUsed;
  final double hoursRemaining;

  const ExpectedStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.courseId,
    this.schedule = const {},
    required this.purchasedHours,
    required this.firstName,
    required this.lastName,
    this.nickName,
    this.qrCodeUrl,
    required this.courseName,
    required this.hoursUsed,
    required this.hoursRemaining,
  });

  factory ExpectedStudent.fromJson(Map<String, dynamic> json) {
    final rawSchedule = json['schedule'];
    final Map<String, List<String>> parsedSchedule = {};
    if (rawSchedule is Map) {
      for (final entry in rawSchedule.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is List) {
          parsedSchedule[key] = value.cast<String>();
        }
      }
    }

    return ExpectedStudent(
      enrollmentId: json['enrollment_id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      schedule: parsedSchedule,
      purchasedHours: (json['purchased_hours'] as num?)?.toInt() ?? 0,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      nickName: json['nick_name'] as String?,
      qrCodeUrl: json['qr_code_url'] as String?,
      courseName: json['course_name'] as String? ?? '',
      hoursUsed: (json['hours_used'] as num?)?.toDouble() ?? 0,
      hoursRemaining: (json['hours_remaining'] as num?)?.toDouble() ?? 0,
    );
  }
}
