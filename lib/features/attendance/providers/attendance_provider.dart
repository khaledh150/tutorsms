import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/attendance_row.dart';
import '../models/course_group.dart';
import '../models/student_for_grid.dart';
import '../repositories/attendance_repository.dart';

final attendanceRepositoryProvider =
    Provider((ref) => AttendanceRepository());

final todayAttendanceProvider = AsyncNotifierProvider<
    TodayAttendanceNotifier, List<AttendanceRow>>(
  TodayAttendanceNotifier.new,
);

class TodayAttendanceNotifier extends AsyncNotifier<List<AttendanceRow>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AttendanceRow>> build() async {
    final repo = ref.read(attendanceRepositoryProvider);
    final schoolId = ref.read(authProvider).valueOrNull?.schoolId;

    _channel?.unsubscribe();
    _channel = supabase
        .channel('attendance_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: schoolId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'school_id',
                  value: schoolId,
                )
              : null,
          callback: (_) => ref.invalidateSelf(),
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return repo.fetchTodayAttendance();
  }

  void refresh() => ref.invalidateSelf();
}

final courseAttendanceProvider = AsyncNotifierProvider.family<
    CourseAttendanceNotifier, List<AttendanceRow>, String>(
  CourseAttendanceNotifier.new,
);

class CourseAttendanceNotifier
    extends FamilyAsyncNotifier<List<AttendanceRow>, String> {
  RealtimeChannel? _channel;

  @override
  Future<List<AttendanceRow>> build(String courseId) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final schoolId = ref.read(authProvider).valueOrNull?.schoolId;

    _channel?.unsubscribe();
    _channel = supabase
        .channel('course_attendance_$courseId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: schoolId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'school_id',
                  value: schoolId,
                )
              : null,
          callback: (_) {
            ref.invalidateSelf();
            ref.invalidate(allTimeHoursProvider(courseId));
          },
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return repo.fetchTodayCourseAttendance(courseId);
  }

  void refresh() => ref.invalidateSelf();
}

final allTimeHoursProvider =
    FutureProvider.family<Map<String, int>, String>((ref, courseId) {
  final repo = ref.read(attendanceRepositoryProvider);
  return repo.fetchAllTimeHoursForCourse(courseId);
});

final courseGroupsProvider =
    FutureProvider<List<CourseGroup>>((ref) async {
  // Watch to rebuild when attendance changes
  ref.watch(todayAttendanceProvider);

  final enrollmentsRes = await supabase
      .from('enrollments')
      .select(
          'student_id,course_id,purchased_hours,initial_used_hours,schedule,courses(id,name),students(first_name,last_name,nick_name,photo_url)')
      .eq('status', 'active');

  final coursesRes =
      await supabase.from('courses').select('id,name');

  final todayWeekday = DateTime.now().weekday % 7;
  final weekdayStr = todayWeekday.toString();

  final groupMap = <String, CourseGroup>{};
  for (final c in (coursesRes as List)) {
    final id = c['id'] as String;
    groupMap[id] = CourseGroup(courseId: id, courseName: c['name'] as String);
  }

  final seenStudents = <String, Set<String>>{};

  for (final e in (enrollmentsRes as List)) {
    final courseId = e['course_id'] as String;
    final studentId = e['student_id'] as String;

    seenStudents[courseId] ??= {};
    if (seenStudents[courseId]!.contains(studentId)) continue;
    seenStudents[courseId]!.add(studentId);

    final courses = e['courses'];
    final courseName =
        courses is Map ? (courses['name'] as String? ?? '') : '';

    if (!groupMap.containsKey(courseId)) {
      groupMap[courseId] = CourseGroup(
        courseId: courseId,
        courseName: courseName,
      );
    }

    final rawSchedule = e['schedule'];
    bool isExpected = false;
    if (rawSchedule is Map) {
      final daySlots = rawSchedule[weekdayStr];
      if (daySlots is List && daySlots.isNotEmpty) {
        isExpected = true;
      }
    }

    final students = e['students'];
    final firstName =
        students is Map ? (students['first_name'] as String? ?? '') : '';
    final lastName =
        students is Map ? (students['last_name'] as String? ?? '') : '';
    final nickName =
        students is Map ? students['nick_name'] as String? : null;
    final photoUrl =
        students is Map ? students['photo_url'] as String? : null;

    groupMap[courseId]!.students.add(StudentForGrid(
      studentId: studentId,
      firstName: firstName,
      lastName: lastName,
      nickName: nickName,
      purchasedHours: (e['purchased_hours'] as num?)?.toInt() ?? 0,
      initialUsedHours: (e['initial_used_hours'] as num?)?.toInt() ?? 0,
      isExpectedToday: isExpected,
      photoUrl: photoUrl,
    ));
  }

  // Sort expected students first within each group
  for (final group in groupMap.values) {
    group.students.sort((a, b) {
      if (a.isExpectedToday != b.isExpectedToday) {
        return a.isExpectedToday ? -1 : 1;
      }
      return 0;
    });
  }

  return groupMap.values.toList();
});

final checkedInSetProvider =
    Provider<Map<String, Set<String>>>((ref) {
  final rows = ref.watch(todayAttendanceProvider).valueOrNull ?? [];
  final map = <String, Set<String>>{};
  for (final r in rows) {
    if (r.approvedBy == null || r.courseId == null) continue;
    map.putIfAbsent(r.courseId!, () => {}).add(r.studentId);
  }
  return map;
});
