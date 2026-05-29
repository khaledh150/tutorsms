class RenewalStudent {
  final String enrollmentId;
  final String studentId;
  final String courseId;
  final int purchasedHours;
  final String firstName;
  final String lastName;
  final String? nickName;
  final String courseName;
  final double hoursUsed;
  final double hoursRemaining;

  const RenewalStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.courseId,
    required this.purchasedHours,
    required this.firstName,
    required this.lastName,
    this.nickName,
    required this.courseName,
    required this.hoursUsed,
    required this.hoursRemaining,
  });

  String get displayName {
    if (nickName != null && nickName!.isNotEmpty && firstName.isNotEmpty) {
      return "$nickName '$firstName'";
    }
    return nickName ?? firstName;
  }

  factory RenewalStudent.fromJson(Map<String, dynamic> json) => RenewalStudent(
        enrollmentId: json['enrollment_id'] as String,
        studentId: json['student_id'] as String,
        courseId: json['course_id'] as String,
        purchasedHours: (json['purchased_hours'] as num?)?.toInt() ?? 0,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        nickName: json['nick_name'] as String?,
        courseName: json['course_name'] as String? ?? '',
        hoursUsed: (json['hours_used'] as num?)?.toDouble() ?? 0,
        hoursRemaining: (json['hours_remaining'] as num?)?.toDouble() ?? 0,
      );
}
