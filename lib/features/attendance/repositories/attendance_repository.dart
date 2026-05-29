import 'package:flutter/foundation.dart';

import '../../../core/supabase_client.dart';
import '../models/attendance_row.dart';

class AttendanceRepository {
  String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);

  Future<List<AttendanceRow>> fetchTodayAttendance() async {
    try {
      final res = await supabase
          .from('attendance')
          .select(
              'id,student_id,course_id,attended_at_ts,approved_by,cancelled_by,cancelled_at')
          .gte('attended_at_ts', _todayStr())
          .isFilter('cancelled_by', null)
          .limit(500);
      return (res as List).map((e) => AttendanceRow.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchTodayAttendance failed: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRow>> fetchTodayCourseAttendance(
      String courseId) async {
    try {
      final res = await supabase
          .from('attendance')
          .select(
              'id,student_id,course_id,attended_at_ts,approved_by,cancelled_by,cancelled_at')
          .eq('course_id', courseId)
          .gte('attended_at_ts', _todayStr())
          .isFilter('cancelled_by', null)
          .limit(500);
      return (res as List).map((e) => AttendanceRow.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchTodayCourseAttendance failed: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRow>> fetchStudentAttendance(String studentId) async {
    try {
      final res = await supabase
          .from('attendance')
          .select('*')
          .eq('student_id', studentId)
          .order('attended_at_ts', ascending: false)
          .limit(500);
      return (res as List).map((e) => AttendanceRow.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchStudentAttendance failed: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRow>> fetchStudentCourseAttendance(
      String studentId, String courseId) async {
    try {
      final res = await supabase
          .from('attendance')
          .select('*')
          .eq('student_id', studentId)
          .eq('course_id', courseId)
          .order('attended_at_ts', ascending: false)
          .limit(500);
      return (res as List).map((e) => AttendanceRow.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchStudentCourseAttendance failed: $e');
      rethrow;
    }
  }

  Future<AttendanceRow> checkIn({
    required String studentId,
    required String courseId,
    required String approverId,
  }) async {
    try {
      final res = await supabase
          .from('attendance')
          .insert({
            'student_id': studentId,
            'course_id': courseId,
            'attended_at_ts': DateTime.now().toIso8601String(),
            'approved_by': approverId,
          })
          .select()
          .single();
      return AttendanceRow.fromJson(res);
    } catch (e) {
      debugPrint('checkIn failed: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRow>> checkInMultiHour({
    required String studentId,
    required String courseId,
    required String approverId,
    required int hours,
    DateTime? date,
  }) async {
    try {
      final ts = date != null
          ? '${date.toIso8601String().substring(0, 10)}T09:00:00'
          : DateTime.now().toIso8601String();
      final inserts = List.generate(
        hours,
        (_) => <String, dynamic>{
          'student_id': studentId,
          'course_id': courseId,
          'attended_at_ts': ts,
          'approved_by': approverId,
        },
      );
      final res =
          await supabase.from('attendance').insert(inserts).select();
      return (res as List).map((e) => AttendanceRow.fromJson(e)).toList();
    } catch (e) {
      debugPrint('checkInMultiHour failed: $e');
      rethrow;
    }
  }

  Future<AttendanceRow> scanCheckIn(String studentId) async {
    try {
      final res = await supabase
          .from('attendance')
          .insert({
            'student_id': studentId,
            'attended_at_ts': _todayStr(),
          })
          .select()
          .single();
      return AttendanceRow.fromJson(res);
    } catch (e) {
      debugPrint('scanCheckIn failed: $e');
      rethrow;
    }
  }

  Future<void> approvePending({
    required String rowId,
    required String courseId,
    required String approverId,
  }) async {
    try {
      await supabase
          .from('attendance')
          .update({
            'course_id': courseId,
            'approved_by': approverId,
          })
          .eq('id', rowId);
    } catch (e) {
      debugPrint('approvePending failed: $e');
      rethrow;
    }
  }

  Future<void> cancelAttendance({
    required String rowId,
    required String userId,
  }) async {
    try {
      await supabase
          .from('attendance')
          .update({
            'cancelled_by': userId,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rowId);
    } catch (e) {
      debugPrint('cancelAttendance failed: $e');
      rethrow;
    }
  }

  Future<void> cancelMultiple({
    required List<String> rowIds,
    required String userId,
  }) async {
    try {
      await supabase
          .from('attendance')
          .update({
            'cancelled_by': userId,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', rowIds);
    } catch (e) {
      debugPrint('cancelMultiple failed: $e');
      rethrow;
    }
  }

  Future<int> getUsedHours(String studentId, String courseId) async {
    try {
      final res = await supabase
          .from('attendance')
          .select('*')
          .eq('student_id', studentId)
          .eq('course_id', courseId)
          .not('approved_by', 'is', null)
          .isFilter('cancelled_by', null)
          .limit(10000);
      return (res as List).length;
    } catch (e) {
      debugPrint('getUsedHours failed: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> fetchAllTimeHoursForCourse(
      String courseId) async {
    try {
      final res = await supabase
          .from('student_course_attendance_summary')
          .select('student_id,course_id,total_hours')
          .eq('course_id', courseId)
          .limit(1000);
      final map = <String, int>{};
      for (final r in (res as List)) {
        final key = '${r['student_id']}|${r['course_id']}';
        map[key] = (r['total_hours'] as num?)?.toInt() ?? 0;
      }
      return map;
    } catch (e) {
      debugPrint('fetchAllTimeHoursForCourse failed: $e');
      rethrow;
    }
  }
}
