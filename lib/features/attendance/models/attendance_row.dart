class AttendanceRow {
  final String id;
  final String studentId;
  final String? courseId;
  final String attendedAtTs;
  final String? approvedBy;
  final String? cancelledBy;
  final String? cancelledAt;

  const AttendanceRow({
    required this.id,
    required this.studentId,
    this.courseId,
    required this.attendedAtTs,
    this.approvedBy,
    this.cancelledBy,
    this.cancelledAt,
  });

  bool get isApproved => approvedBy != null;
  bool get isCancelled => cancelledBy != null;
  bool get isPending => !isApproved && !isCancelled;

  factory AttendanceRow.fromJson(Map<String, dynamic> json) => AttendanceRow(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        courseId: json['course_id'] as String?,
        attendedAtTs: json['attended_at_ts'] as String? ?? '',
        approvedBy: json['approved_by'] as String?,
        cancelledBy: json['cancelled_by'] as String?,
        cancelledAt: json['cancelled_at'] as String?,
      );
}
