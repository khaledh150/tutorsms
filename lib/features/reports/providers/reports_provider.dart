import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reports_repository.dart';

final reportsRepositoryProvider = Provider((ref) => ReportsRepository());

final attendanceStats30dProvider =
    FutureProvider<Map<String, int>>((ref) {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.fetchAttendanceStats30d();
});

final courseUtilizationProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.fetchCourseUtilization();
});

final attendanceByDayProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String? from, String? to})>((ref, params) {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.fetchAttendanceByDay(from: params.from, to: params.to);
});

final attendanceRecordsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String date, String? courseId})>((ref, params) {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.fetchAttendanceRecords(
    date: params.date,
    courseId: params.courseId,
  );
});
