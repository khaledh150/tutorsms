import '../../../core/supabase_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  Future<List<AppNotification>> fetchUnread({int limit = 20}) async {
    final res = await supabase
        .from('notifications')
        .select('*')
        .eq('read', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<int> countUnread() async {
    final res = await supabase
        .from('notifications')
        .select('id')
        .eq('read', false)
        .count();
    return res.count;
  }

  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'read': true})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    await supabase
        .from('notifications')
        .update({'read': true})
        .eq('read', false);
  }
}
