import '../../../core/supabase_client.dart';

class SettingsRepository {
  Future<List<Map<String, dynamic>>> fetchProfiles({
    String? schoolId,
  }) async {
    var query = supabase
        .from('profiles')
        .select('id,email,full_name,role,username');
    if (schoolId != null) query = query.eq('school_id', schoolId);
    final res = await query.order('role', ascending: false).limit(200);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createStaffUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await supabase.rpc('create_staff_user', params: {
      'p_email': email,
      'p_password': password,
      'p_full_name': fullName,
      'p_role': role,
    });
  }

  Future<void> updateProfile(String id, Map<String, dynamic> updates) async {
    await supabase.from('profiles').update(updates).eq('id', id);
  }

  Future<void> updateUsername(String userId, String newUsername) async {
    await supabase.rpc('update_staff_username', params: {
      'p_user_id': userId,
      'p_new_username': newUsername,
    });
  }

  Future<void> updatePassword(String userId, String newPassword) async {
    await supabase.rpc('update_staff_password', params: {
      'p_user_id': userId,
      'p_new_password': newPassword,
    });
  }

  Future<void> deleteProfile(String id) async {
    await supabase.from('profiles').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchAuditLog({
    int offset = 0,
    int limit = 50,
    String? actionFilter,
  }) async {
    var query = supabase
        .from('audit_log')
        .select('*');
    if (actionFilter != null && actionFilter.isNotEmpty) {
      query = query.eq('action', actionFilter);
    }
    final res = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, String>> fetchActorNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    final res = await supabase
        .from('profiles')
        .select('id,full_name,username')
        .inFilter('id', ids)
        .limit(500);
    final map = <String, String>{};
    for (final p in (res as List)) {
      map[p['id'] as String] =
          (p['full_name'] as String?) ?? (p['username'] as String?) ?? 'Unknown';
    }
    return map;
  }
}
