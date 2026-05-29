import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/application_change_model.dart';
import '../models/application_model.dart';
import '../repositories/application_repository.dart';

final applicationRepositoryProvider =
    Provider((ref) => ApplicationRepository());

final pendingApplicationsProvider = AsyncNotifierProvider<
    PendingApplicationsNotifier, List<Application>>(
  PendingApplicationsNotifier.new,
);

class PendingApplicationsNotifier extends AsyncNotifier<List<Application>> {
  @override
  Future<List<Application>> build() {
    final repo = ref.read(applicationRepositoryProvider);
    return repo.fetchPendingApplications();
  }

  void refresh() => ref.invalidateSelf();
}

final pendingChangesProvider = AsyncNotifierProvider<
    PendingChangesNotifier, List<ApplicationChange>>(
  PendingChangesNotifier.new,
);

class PendingChangesNotifier
    extends AsyncNotifier<List<ApplicationChange>> {
  @override
  Future<List<ApplicationChange>> build() {
    final repo = ref.read(applicationRepositoryProvider);
    return repo.fetchPendingChanges();
  }

  void refresh() => ref.invalidateSelf();
}

final pendingReviewCountProvider =
    FutureProvider<int>((ref) {
  ref.watch(pendingApplicationsProvider);
  ref.watch(pendingChangesProvider);
  final repo = ref.read(applicationRepositoryProvider);
  return repo.countPendingReviews();
});

final studentPendingChangesProvider =
    FutureProvider.family<List<ApplicationChange>, String>(
        (ref, studentId) {
  final repo = ref.read(applicationRepositoryProvider);
  return repo.fetchPendingChangesForStudent(studentId);
});
