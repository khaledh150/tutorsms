import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/line_config_model.dart';
import '../models/line_connection_model.dart';
import '../models/unlinked_user_model.dart';
import '../repositories/messaging_repository.dart';

final messagingRepositoryProvider =
    Provider((ref) => MessagingRepository());

final lineConfigProvider =
    AsyncNotifierProvider<LineConfigNotifier, LineConfig?>(
  LineConfigNotifier.new,
);

class LineConfigNotifier extends AsyncNotifier<LineConfig?> {
  @override
  Future<LineConfig?> build() {
    return ref.read(messagingRepositoryProvider).fetchLineConfig();
  }

  void refresh() => ref.invalidateSelf();
}

final lineMessagesProvider =
    AsyncNotifierProvider<LineMessagesNotifier, List<LineMessage>>(
  LineMessagesNotifier.new,
);

class LineMessagesNotifier extends AsyncNotifier<List<LineMessage>> {
  RealtimeChannel? _channel;

  @override
  Future<List<LineMessage>> build() {
    final schoolId = ref.read(authProvider).valueOrNull?.schoolId;

    _channel?.unsubscribe();
    _channel = supabase
        .channel('line_messages_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'line_messages',
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

    return ref.read(messagingRepositoryProvider).fetchMessages();
  }

  void refresh() => ref.invalidateSelf();
}

final lineConnectionsProvider =
    AsyncNotifierProvider<LineConnectionsNotifier, List<LineConnection>>(
  LineConnectionsNotifier.new,
);

class LineConnectionsNotifier
    extends AsyncNotifier<List<LineConnection>> {
  @override
  Future<List<LineConnection>> build() {
    return ref.read(messagingRepositoryProvider).fetchConnections();
  }

  void refresh() => ref.invalidateSelf();
}

final unlinkedUsersProvider = AsyncNotifierProvider<
    UnlinkedUsersNotifier, List<UnlinkedLineUser>>(
  UnlinkedUsersNotifier.new,
);

class UnlinkedUsersNotifier
    extends AsyncNotifier<List<UnlinkedLineUser>> {
  @override
  Future<List<UnlinkedLineUser>> build() {
    return ref.read(messagingRepositoryProvider).fetchUnlinkedUsers();
  }

  void refresh() => ref.invalidateSelf();
}

final activeEnrollmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .read(messagingRepositoryProvider)
      .fetchActiveEnrollments();
});

final connectedStudentIdsProvider = Provider<Set<String>>((ref) {
  final connections = ref.watch(lineConnectionsProvider).valueOrNull ?? [];
  return connections.map((c) => c.studentId).toSet();
});

final studentConnectionProvider =
    FutureProvider.family<LineConnection?, String>(
        (ref, studentId) {
  return ref
      .read(messagingRepositoryProvider)
      .fetchConnectionForStudent(studentId);
});
