import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/school_model.dart';
import '../repositories/super_admin_repository.dart';

final superAdminRepositoryProvider =
    Provider((ref) => SuperAdminRepository());

final schoolsProvider =
    AsyncNotifierProvider<SchoolsNotifier, List<SchoolHealth>>(
        SchoolsNotifier.new);

class SchoolsNotifier extends AsyncNotifier<List<SchoolHealth>> {
  @override
  Future<List<SchoolHealth>> build() {
    return ref.read(superAdminRepositoryProvider).fetchSchools();
  }

  void refresh() => ref.invalidateSelf();
}

final recentActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(superAdminRepositoryProvider).fetchRecentActivity();
});

final attendanceTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(superAdminRepositoryProvider).fetchAttendanceTrend();
});

final expiringTrialsProvider = FutureProvider<List<SchoolHealth>>((ref) {
  return ref.read(superAdminRepositoryProvider).fetchExpiringTrials();
});

/// Tracks whether a super admin is currently impersonating a school.
/// Reads from SharedPreferences on init so it survives hot restarts.
final impersonationProvider =
    AsyncNotifierProvider<ImpersonationNotifier, ImpersonationState>(
        ImpersonationNotifier.new);

class ImpersonationState {
  final bool active;
  final String? schoolName;

  const ImpersonationState({this.active = false, this.schoolName});
}

class ImpersonationNotifier extends AsyncNotifier<ImpersonationState> {
  @override
  Future<ImpersonationState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getString('sa_original_school_id') != null;
    final schoolName = prefs.getString('sa_impersonate_school_name');
    return ImpersonationState(active: isActive, schoolName: schoolName);
  }

  Future<void> startImpersonation(
      String targetSchoolId, String schoolName) async {
    final repo = ref.read(superAdminRepositoryProvider);
    await repo.startImpersonation(targetSchoolId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sa_impersonate_school_name', schoolName);

    state = AsyncData(
        ImpersonationState(active: true, schoolName: schoolName));
  }

  Future<void> stopImpersonation() async {
    final repo = ref.read(superAdminRepositoryProvider);
    await repo.stopImpersonation();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sa_impersonate_school_name');

    state = const AsyncData(ImpersonationState());
  }
}
