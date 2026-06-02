import 'package:flutter/foundation.dart';

import '../../../core/supabase_client.dart';
import '../models/course_model.dart';
import '../models/course_time_model.dart';

class CourseRepository {
  Future<List<Course>> fetchCourses() async {
    try {
      final res =
          await supabase.from('courses').select('*').order('name').limit(200);
      return (res as List).map((e) => Course.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchCourses failed: $e');
      rethrow;
    }
  }

  Future<Course> fetchCourse(String id) async {
    try {
      final res =
          await supabase.from('courses').select('*').eq('id', id).single();
      return Course.fromJson(res);
    } catch (e) {
      debugPrint('fetchCourse failed: $e');
      rethrow;
    }
  }

  Future<List<CourseTime>> fetchCourseTimes(String courseId) async {
    try {
      final res = await supabase
          .from('course_times')
          .select('*')
          .eq('course_id', courseId)
          .order('weekday')
          .limit(100);
      return (res as List).map((e) => CourseTime.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchCourseTimes failed: $e');
      rethrow;
    }
  }

  String getTodayWeekday() {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[DateTime.now().weekday % 7];
  }

  Future<List<Course>> fetchCoursesForToday() async {
    try {
      final today = getTodayWeekday();
      final res = await supabase
          .from('courses')
          .select('*')
          .contains('weekdays', [today]).order('name').limit(200);
      return (res as List).map((e) => Course.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchCoursesForToday failed: $e');
      rethrow;
    }
  }

  Future<Course> createCourse(Map<String, dynamic> data) async {
    try {
      final res = await supabase
          .from('courses')
          .insert([data])
          .select()
          .single();
      return Course.fromJson(res);
    } catch (e) {
      debugPrint('createCourse failed: $e');
      rethrow;
    }
  }

  Future<Course> updateCourse(String id, Map<String, dynamic> updates) async {
    try {
      final res = await supabase
          .from('courses')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return Course.fromJson(res);
    } catch (e) {
      debugPrint('updateCourse failed: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      await supabase.from('courses').delete().eq('id', id);
    } catch (e) {
      debugPrint('deleteCourse failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCourseOverview() async {
    try {
      final res = await supabase.from('course_overview').select('*').limit(200);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchCourseOverview failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudentsForCourse(
      String courseId) async {
    try {
      final res = await supabase
          .from('enrollments')
          .select('student_id, students(id, first_name, last_name, nick_name)')
          .eq('course_id', courseId)
          .eq('status', 'active')
          .limit(500);

      final seen = <String>{};
      final results = <Map<String, dynamic>>[];
      for (final e in (res as List)) {
        final s = e['students'];
        if (s is! Map) continue;
        final id = s['id'] as String?;
        if (id == null) continue;
        if (seen.add(id)) {
          results.add(Map<String, dynamic>.from(s));
        }
      }
      return results;
    } catch (e) {
      debugPrint('fetchStudentsForCourse failed: $e');
      rethrow;
    }
  }
}
