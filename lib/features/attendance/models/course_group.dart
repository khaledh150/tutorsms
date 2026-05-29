import 'student_for_grid.dart';

class CourseGroup {
  final String courseId;
  final String courseName;
  final List<StudentForGrid> students;

  CourseGroup({
    required this.courseId,
    required this.courseName,
    List<StudentForGrid>? students,
  }) : students = students ?? [];
}
