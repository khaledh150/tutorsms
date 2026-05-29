class Enrollment {
  final String id;
  final String studentId;
  final String courseId;
  final int purchasedHours;
  final int initialUsedHours;
  final Map<String, List<String>> schedule;
  final String status;
  final String? createdAt;
  final String? cancelledAt;
  final String? cancelledBy;
  final String? courseName;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.courseId,
    this.purchasedHours = 0,
    this.initialUsedHours = 0,
    this.schedule = const {},
    this.status = 'active',
    this.createdAt,
    this.cancelledAt,
    this.cancelledBy,
    this.courseName,
  });

  int usedHours(int attendanceCount) => attendanceCount + initialUsedHours;

  int remainingHours(int attendanceCount) =>
      purchasedHours - usedHours(attendanceCount);

  bool isOverlimit(int attendanceCount) =>
      purchasedHours > 0 && remainingHours(attendanceCount) <= 0;

  bool isApproaching(int attendanceCount) {
    final rem = remainingHours(attendanceCount);
    return purchasedHours > 0 && rem > 0 && rem <= 2;
  }

  factory Enrollment.fromJson(Map<String, dynamic> json) {
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

    final courses = json['courses'];
    String? courseName;
    if (courses is Map) {
      courseName = courses['name'] as String?;
    }

    return Enrollment(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      purchasedHours: (json['purchased_hours'] as num?)?.toInt() ?? 0,
      initialUsedHours: (json['initial_used_hours'] as num?)?.toInt() ?? 0,
      schedule: parsedSchedule,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      courseName: courseName,
    );
  }
}

class EnrollmentHistoryRecord {
  final String id;
  final String studentId;
  final String courseId;
  final String courseName;
  final int purchasedHours;
  final int usedHours;
  final int? price;
  final String? bookInfo;
  final String? receiptUrl;
  final String renewedAt;

  const EnrollmentHistoryRecord({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseName,
    this.purchasedHours = 0,
    this.usedHours = 0,
    this.price,
    this.bookInfo,
    this.receiptUrl,
    required this.renewedAt,
  });

  factory EnrollmentHistoryRecord.fromJson(Map<String, dynamic> json) =>
      EnrollmentHistoryRecord(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        courseId: json['course_id'] as String,
        courseName: json['course_name'] as String? ?? '',
        purchasedHours: (json['purchased_hours'] as num?)?.toInt() ?? 0,
        usedHours: (json['used_hours'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toInt(),
        bookInfo: json['book_info'] as String?,
        receiptUrl: json['receipt_url'] as String?,
        renewedAt: json['renewed_at'] as String? ?? '',
      );
}
