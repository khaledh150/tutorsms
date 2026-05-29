import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase_client.dart';
import '../models/school_model.dart';

class SuperAdminRepository {
  Future<List<SchoolHealth>> fetchSchools() async {
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('school_health').select().limit(200),
        supabase.rpc('get_school_owner_logins'),
      ]);

      final healthData = results[0] as List<dynamic>;
      final logins = results[1] as List<dynamic>? ?? [];

      final loginMap = <String, String>{};
      for (final l in logins) {
        final m = l as Map<String, dynamic>;
        loginMap[m['school_id'] as String] = m['owner_last_login'] as String;
      }

      return healthData.map((raw) {
        final m = raw as Map<String, dynamic>;
        m['owner_last_login'] = loginMap[m['school_id']];
        return SchoolHealth.fromJson(m);
      }).toList();
    } catch (e) {
      debugPrint('fetchSchools failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentActivity() async {
    try {
      final data = await supabase
          .from('audit_log')
          .select('id,action,target_type,target_id,metadata,created_at,actor_id,school_id')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('fetchRecentActivity failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceTrend() async {
    try {
      final data = await supabase.rpc('get_platform_attendance_trend');
      return List<Map<String, dynamic>>.from(data ?? []);
    } catch (_) {
      try {
        final cutoff = DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String();
        final fallback = await supabase
            .from('attendance')
            .select('attended_at_ts')
            .gte('attended_at_ts', cutoff)
            .limit(10000);
        final byDay = <String, int>{};
        for (final a in fallback) {
          final day = (a['attended_at_ts'] as String).substring(0, 10);
          byDay[day] = (byDay[day] ?? 0) + 1;
        }
        final entries = byDay.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .map((e) => {'date': e.key, 'count': e.value})
            .toList();
      } catch (e) {
        debugPrint('fetchAttendanceTrend failed: $e');
        rethrow;
      }
    }
  }

  Future<void> createSchool({
    required String name,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String plan = 'basic',
    int maxStudents = 50,
    int maxStaff = 5,
    String? notes,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
    String? trialDuration, // '7d', '30d', '6m', '1y'
  }) async {
    try {
      DateTime? trialEnd;
      if (trialDuration != null) {
        final now = DateTime.now();
        switch (trialDuration) {
          case '7d': trialEnd = now.add(const Duration(days: 7));
          case '30d': trialEnd = now.add(const Duration(days: 30));
          case '6m': trialEnd = DateTime(now.year, now.month + 6, now.day);
          case '1y': trialEnd = DateTime(now.year + 1, now.month, now.day);
        }
      }

      final school = await supabase
          .from('schools')
          .insert({
            'name': name,
            'contact_email': contactEmail,
            'contact_phone': contactPhone,
            'address': address,
            'plan': plan,
            'max_students': maxStudents,
            'max_staff': maxStaff,
            'notes': notes,
            'status': trialDuration != null ? 'free' : 'active',
            'trial_ends_at': trialEnd?.toIso8601String(),
            'trial_duration': trialDuration,
          })
          .select()
          .single();

      final authRes = await supabase.auth.signUp(
        email: adminEmail,
        password: adminPassword,
      );
      final newUser = authRes.user;
      if (newUser == null) throw Exception('Failed to create auth user');

      await supabase.from('profiles').upsert({
        'id': newUser.id,
        'email': adminEmail,
        'full_name': adminName,
        'role': 'owner',
        'school_id': school['id'],
        'username': adminEmail.split('@').first,
      });

      await supabase
          .from('schools')
          .update({'owner_id': newUser.id})
          .eq('id', school['id']);

      final me = supabase.auth.currentUser;
      await supabase.rpc('log_audit', params: {
        'p_actor_id': me?.id,
        'p_school_id': school['id'],
        'p_action': 'school_created',
        'p_target_type': 'school',
        'p_target_id': school['id'],
        'p_metadata': {
          'school_name': name,
          'owner_email': adminEmail,
          'trial_duration': trialDuration,
        },
      });
    } catch (e) {
      debugPrint('createSchool failed: $e');
      rethrow;
    }
  }

  Future<List<SchoolHealth>> fetchExpiringTrials({int withinDays = 7}) async {
    try {
      final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String();
      final now = DateTime.now().toIso8601String();
      final res = await supabase
          .from('school_health')
          .select()
          .eq('status', 'free')
          .not('trial_ends_at', 'is', null)
          .lte('trial_ends_at', cutoff)
          .gte('trial_ends_at', now)
          .limit(100);
      return (res as List).map((r) => SchoolHealth.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('fetchExpiringTrials failed: $e');
      rethrow;
    }
  }

  Future<void> updateSchoolStatus(String schoolId, String status) async {
    try {
      await supabase
          .from('schools')
          .update({'status': status})
          .eq('id', schoolId);

      final me = supabase.auth.currentUser;
      await supabase.rpc('log_audit', params: {
        'p_actor_id': me?.id,
        'p_school_id': schoolId,
        'p_action': 'school_$status',
        'p_target_type': 'school',
        'p_target_id': schoolId,
      });
    } catch (e) {
      debugPrint('updateSchoolStatus failed: $e');
      rethrow;
    }
  }

  /// Impersonation: save original school_id, then update the profile to the
  /// target school's id. Supabase RLS will then scope all queries to that
  /// school.
  Future<void> startImpersonation(String targetSchoolId) async {
    try {
      final me = supabase.auth.currentUser;
      if (me == null) return;

      final myProfile = await supabase
          .from('profiles')
          .select('school_id')
          .eq('id', me.id)
          .single();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sa_original_school_id', myProfile['school_id'] as String);
      await prefs.setString('sa_impersonate_uid', me.id);

      await supabase
          .from('profiles')
          .update({'school_id': targetSchoolId})
          .eq('id', me.id);
    } catch (e) {
      debugPrint('startImpersonation failed: $e');
      rethrow;
    }
  }

  /// End impersonation: restore the original school_id.
  Future<void> stopImpersonation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final originalSchoolId = prefs.getString('sa_original_school_id');
      final uid = prefs.getString('sa_impersonate_uid');

      if (uid != null && originalSchoolId != null) {
        await supabase
            .from('profiles')
            .update({'school_id': originalSchoolId})
            .eq('id', uid);
      }

      await prefs.remove('sa_original_school_id');
      await prefs.remove('sa_impersonate_uid');
    } catch (e) {
      debugPrint('stopImpersonation failed: $e');
      rethrow;
    }
  }

  /// Check if currently impersonating.
  Future<bool> isImpersonating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('sa_original_school_id') != null;
    } catch (e) {
      debugPrint('isImpersonating failed: $e');
      rethrow;
    }
  }
}
