import 'package:flutter/foundation.dart';

import '../../../core/supabase_client.dart';

class ReportsRepository {
  Future<Map<String, int>> fetchAttendanceStats30d() async {
    try {
      final res = await supabase
          .from('attendance_stats_30d')
          .select('total_checkins, unique_students, active_days')
          .limit(1)
          .maybeSingle();
      if (res == null) {
        return {'total_checkins': 0, 'unique_students': 0, 'active_days': 0};
      }
      return {
        'total_checkins': (res['total_checkins'] as num?)?.toInt() ?? 0,
        'unique_students': (res['unique_students'] as num?)?.toInt() ?? 0,
        'active_days': (res['active_days'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('fetchAttendanceStats30d failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCourseUtilization() async {
    try {
      final res = await supabase
          .from('course_utilization')
          .select(
              'course_id, course_name, capacity, enrolled, checkins_30d')
          .limit(200);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('fetchCourseUtilization failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceByDay({
    String? from,
    String? to,
  }) async {
    try {
      final toDate = to != null && to.isNotEmpty
          ? (DateTime.tryParse(to) ?? DateTime.now())
          : DateTime.now();
      final fromDate = from != null && from.isNotEmpty
          ? (DateTime.tryParse(from) ?? toDate.subtract(const Duration(days: 29)))
          : toDate.subtract(const Duration(days: 29));
      final daysBack = toDate.difference(fromDate).inDays.clamp(1, 365);

      final res = await supabase.rpc('get_attendance_by_day', params: {'days_back': daysBack});
      final counts = <String, int>{};
      for (final r in (res as List)) {
        final day = r['day'] as String;
        counts[day] = (r['count'] as num).toInt();
      }

      final result = <Map<String, dynamic>>[];
      for (var i = daysBack; i >= 0; i--) {
        final d = toDate.subtract(Duration(days: i));
        final key = d.toIso8601String().substring(0, 10);
        result.add({'date': key.substring(5), 'count': counts[key] ?? 0});
      }
      return result;
    } catch (e) {
      debugPrint('fetchAttendanceByDay failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceRecords({
    required String date,
    String? courseId,
  }) async {
    try {
      var query = supabase
          .from('attendance')
          .select('student_id, course_id, attended_at_ts')
          .not('approved_by', 'is', null)
          .isFilter('cancelled_by', null)
          .gte('attended_at_ts', date)
          .lte('attended_at_ts', '${date}T23:59:59');
      if (courseId != null && courseId.isNotEmpty) {
        query = query.eq('course_id', courseId);
      }
      final res = await query
          .order('attended_at_ts', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('fetchAttendanceRecords failed: $e');
      rethrow;
    }
  }
}
