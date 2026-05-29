class StudentNote {
  final String id;
  final String studentId;
  final String createdBy;
  final String note;
  final String category;
  final String? createdAt;
  final String? authorName;

  const StudentNote({
    required this.id,
    required this.studentId,
    required this.createdBy,
    required this.note,
    this.category = 'general',
    this.createdAt,
    this.authorName,
  });

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'];
    String? authorName;
    if (profiles is Map) {
      authorName = profiles['full_name'] as String?;
    }

    return StudentNote(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      createdBy: json['created_by'] as String? ?? '',
      note: json['note'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      createdAt: json['created_at'] as String?,
      authorName: authorName,
    );
  }
}
