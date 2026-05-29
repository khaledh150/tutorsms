import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expected_student.dart';
import '../models/renewal_student.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider =
    Provider((ref) => DashboardRepository());

final expectedTodayProvider =
    FutureProvider<List<ExpectedStudent>>((ref) {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.fetchExpectedToday();
});

final renewalStudentsProvider =
    FutureProvider<List<RenewalStudent>>((ref) {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.fetchRenewalStudents();
});

final todayAttendanceProvider =
    AsyncNotifierProvider<TodayAttendanceNotifier, List<Map<String, dynamic>>>(
        TodayAttendanceNotifier.new);

class TodayAttendanceNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  RealtimeChannel? _channel;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final schoolId = ref.read(authProvider).valueOrNull?.schoolId;

    _channel?.unsubscribe();
    _channel = supabase
        .channel('home_attendance_realtime')
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
      _channel = null;
    });

    final repo = ref.read(dashboardRepositoryProvider);
    return repo.fetchTodayAttendance();
  }
}

final pendingReviewCountProvider = FutureProvider<int>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || !user.isAdmin) return 0;
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.countPendingReviews();
});

final dashboardStudentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.fetchStudents();
});

final schoolNameProvider = FutureProvider<String?>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.schoolId == null) return null;
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.fetchSchoolName(user.schoolId!);
});
