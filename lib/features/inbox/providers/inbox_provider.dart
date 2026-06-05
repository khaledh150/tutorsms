import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../admissions/providers/application_provider.dart';
import '../../courses/providers/course_provider.dart';
import '../../students/repositories/student_repository.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

final studentNameMapProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final changes = ref.watch(pendingChangesProvider).valueOrNull ?? [];
  final studentIds =
      changes.map((c) => c.studentId).where((id) => id.isNotEmpty).toSet();
  if (studentIds.isEmpty) return {};
  final repo = StudentRepository();
  return repo.fetchStudentNameMap(studentIds.toList());
});

final courseNameMapProvider = Provider<Map<String, String>>((ref) {
  final courses = ref.watch(coursesProvider).valueOrNull ?? [];
  return {for (final c in courses) c.id: c.name};
});

final staffNameMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final res = await supabase.from('profiles').select('id,full_name,username').limit(200);
  final map = <String, String>{};
  for (final p in (res as List)) {
    final id = p['id'] as String;
    map[id] = (p['full_name'] as String?)?.isNotEmpty == true
        ? p['full_name'] as String
        : (p['username'] as String?) ?? id.substring(0, 8);
  }
  return map;
});

final totalPendingProvider = Provider<int>((ref) {
  final apps = ref.watch(pendingApplicationsProvider).valueOrNull ?? [];
  final changes = ref.watch(pendingChangesProvider).valueOrNull ?? [];
  return apps.length + changes.length;
});

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

final unreadNotificationsProvider =
    AsyncNotifierProvider<UnreadNotificationsNotifier, List<AppNotification>>(
        UnreadNotificationsNotifier.new);

class UnreadNotificationsNotifier
    extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    return repo.fetchUnread();
  }

  Future<void> markRead(String id) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markRead(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((n) => n.id != id).toList(),
    );
  }

  Future<void> markAllRead() async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAllRead();
    state = const AsyncData([]);
  }

  void refresh() => ref.invalidateSelf();
}

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(unreadNotificationsProvider).valueOrNull?.length ?? 0;
});
