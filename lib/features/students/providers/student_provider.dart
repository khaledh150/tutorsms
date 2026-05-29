import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admissions/models/application_change_model.dart';
import '../../admissions/repositories/application_repository.dart';
import '../models/enrollment_model.dart';
import '../models/student_model.dart';
import '../models/student_note.dart';
import '../repositories/student_repository.dart';

final studentRepositoryProvider = Provider((ref) => StudentRepository());

// --- Students with status (3-tab view) ---

final studentsWithStatusProvider =
    AsyncNotifierProvider<StudentsWithStatusNotifier, List<StudentWithStatus>>(
        StudentsWithStatusNotifier.new);

class StudentsWithStatusNotifier
    extends AsyncNotifier<List<StudentWithStatus>> {
  @override
  Future<List<StudentWithStatus>> build() {
    final repo = ref.read(studentRepositoryProvider);
    return repo.fetchStudentsWithStatus();
  }

  void refresh() => ref.invalidateSelf();
}

// --- Single student ---

final studentProvider =
    FutureProvider.family<Student, String>((ref, id) {
  final repo = ref.read(studentRepositoryProvider);
  return repo.fetchStudent(id);
});

// --- Enrollments for a student ---

final studentEnrollmentsProvider =
    FutureProvider.family<List<Enrollment>, String>((ref, studentId) {
  final repo = ref.read(studentRepositoryProvider);
  return repo.fetchStudentEnrollments(studentId);
});

// --- Attendance for a student ---

final studentAttendanceProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, studentId) {
  final repo = ref.read(studentRepositoryProvider);
  return repo.fetchStudentAttendance(studentId);
});

// --- Enrollment history ---

final enrollmentHistoryProvider =
    FutureProvider.family<List<EnrollmentHistoryRecord>, String>(
        (ref, studentId) {
  final repo = ref.read(studentRepositoryProvider);
  return repo.fetchEnrollmentHistory(studentId);
});

// --- Student notes ---

final studentNotesProvider =
    AsyncNotifierProvider.family<StudentNotesNotifier, List<StudentNote>,
        String>(StudentNotesNotifier.new);

class StudentNotesNotifier
    extends FamilyAsyncNotifier<List<StudentNote>, String> {
  @override
  Future<List<StudentNote>> build(String studentId) {
    final repo = ref.read(studentRepositoryProvider);
    return repo.fetchStudentNotes(studentId);
  }

  Future<void> addNote({
    required String createdBy,
    required String note,
    String category = 'general',
  }) async {
    final repo = ref.read(studentRepositoryProvider);
    await repo.addStudentNote(
      studentId: arg,
      createdBy: createdBy,
      note: note,
      category: category,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteNote(String noteId) async {
    final repo = ref.read(studentRepositoryProvider);
    await repo.deleteStudentNote(noteId);
    ref.invalidateSelf();
  }
}

// --- All students (for messaging, admissions, etc.) ---

final allStudentsProvider = FutureProvider<List<Student>>((ref) {
  final repo = ref.read(studentRepositoryProvider);
  return repo.fetchStudents(activeOnly: false);
});

// --- Pending changes for a student ---

final pendingChangesForStudentProvider =
    FutureProvider.family<List<ApplicationChange>, String>(
        (ref, studentId) {
  final repo = ApplicationRepository();
  return repo.fetchPendingChangesForStudent(studentId);
});

// --- Search state ---

final studentSearchQueryProvider = StateProvider<String>((ref) => '');
