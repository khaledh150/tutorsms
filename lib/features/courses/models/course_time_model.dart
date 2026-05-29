class CourseTime {
  final String id;
  final String courseId;
  final String weekday;
  final String start;
  final String end;

  const CourseTime({
    required this.id,
    required this.courseId,
    required this.weekday,
    required this.start,
    required this.end,
  });

  factory CourseTime.fromJson(Map<String, dynamic> json) => CourseTime(
        id: json['id'] as String,
        courseId: json['course_id'] as String,
        weekday: json['weekday'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
      );

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'weekday': weekday,
        'start': start,
        'end': end,
      };
}
