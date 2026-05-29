import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_model.dart';
import '../repositories/course_repository.dart';

final courseRepositoryProvider = Provider((ref) => CourseRepository());

final coursesProvider =
    AsyncNotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class CoursesNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final repo = ref.read(courseRepositoryProvider);
    return repo.fetchCourses();
  }

  Future<void> createCourse(Map<String, dynamic> data) async {
    final repo = ref.read(courseRepositoryProvider);
    await repo.createCourse(data);
    ref.invalidateSelf();
  }

  Future<void> updateCourse(String id, Map<String, dynamic> updates) async {
    final repo = ref.read(courseRepositoryProvider);
    await repo.updateCourse(id, updates);
    ref.invalidateSelf();
  }

  Future<void> deleteCourse(String id) async {
    final repo = ref.read(courseRepositoryProvider);
    await repo.deleteCourse(id);
    ref.invalidateSelf();
  }
}

final coursesTodayProvider = FutureProvider<List<Course>>((ref) {
  final repo = ref.read(courseRepositoryProvider);
  return repo.fetchCoursesForToday();
});

final courseOverviewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.read(courseRepositoryProvider);
  return repo.fetchCourseOverview();
});

final studentsForCourseProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, courseId) {
  final repo = ref.read(courseRepositoryProvider);
  return repo.fetchStudentsForCourse(courseId);
});
