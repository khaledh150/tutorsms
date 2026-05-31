import 'package:flutter/foundation.dart';

import '../../../core/supabase_client.dart';
import '../models/expected_student.dart';
import '../models/renewal_student.dart';

class DashboardRepository {
  Future<List<ExpectedStudent>> fetchExpectedToday() async {
    try {
      final res = await supabase
          .from('expected_students_today')
          .select('*')
          .order('course_name')
          .limit(500);
      return (res as List).map((e) => ExpectedStudent.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchExpectedToday failed: $e');
      rethrow;
    }
  }

  Future<List<RenewalStudent>> fetchRenewalStudents() async {
    try {
      final res = await supabase
          .from('renewal_students')
          .select('*')
          .lte('hours_remaining', 2)
          .order('hours_remaining')
          .limit(500);
      return (res as List).map((e) => RenewalStudent.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchRenewalStudents failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTodayAttendance() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await supabase
          .from('attendance')
          .select('id,student_id,course_id,attended_at_ts,approved_by,courses(name)')
          .gte('attended_at_ts', today)
          .not('approved_by', 'is', null)
          .order('attended_at_ts', ascending: false)
          .limit(500);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchTodayAttendance failed: $e');
      rethrow;
    }
  }

  Future<int> countPendingReviews() async {
    try {
      final results = await Future.wait([
        supabase
            .from('applications')
            .select('id')
            .eq('status', 'pending')
            .count(),
        supabase
            .from('application_changes')
            .select('id')
            .eq('status', 'pending')
            .count(),
      ]);
      return results[0].count + results[1].count;
    } catch (e) {
      debugPrint('countPendingReviews failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudents() async {
    try {
      final res = await supabase
          .from('students')
          .select(
              'id,first_name,last_name,nick_name,status')
          .or('status.eq.active,status.is.null')
          .order('joined_at', ascending: false)
          .limit(1000);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchStudents failed: $e');
      rethrow;
    }
  }

  Future<String?> fetchSchoolName(String schoolId) async {
    try {
      final res = await supabase
          .from('schools')
          .select('name')
          .eq('id', schoolId)
          .maybeSingle();
      return res?['name'] as String?;
    } catch (e) {
      debugPrint('fetchSchoolName failed: $e');
      rethrow;
    }
  }
}
