import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../models/enrollment_model.dart';
import '../models/student_model.dart';
import '../models/student_note.dart';

class StudentRepository {
  Future<List<Student>> fetchStudents({bool activeOnly = true}) async {
    try {
      final baseQuery = supabase.from('students').select(
          'id,first_name,last_name,nick_name,parent_phone,parent_line_id,joined_at,status,qr_code_url,photo_url');
      final filtered = activeOnly
          ? baseQuery.or('status.eq.active,status.is.null')
          : baseQuery;
      final res = await filtered.order('joined_at', ascending: false).limit(1000);
      return (res as List).map((e) => Student.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchStudents failed: $e');
      rethrow;
    }
  }

  Future<List<Student>> fetchInactiveStudents() async {
    try {
      final res = await supabase
          .from('students')
          .select(
              'id,first_name,last_name,nick_name,parent_phone,parent_line_id,joined_at,status,qr_code_url,photo_url')
          .eq('status', 'inactive')
          .order('joined_at', ascending: false)
          .limit(1000);
      return (res as List).map((e) => Student.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchInactiveStudents failed: $e');
      rethrow;
    }
  }

  Future<Student> fetchStudent(String id) async {
    try {
      final res =
          await supabase.from('students').select('*').eq('id', id).single();
      return Student.fromJson(res);
    } catch (e) {
      debugPrint('fetchStudent failed: $e');
      rethrow;
    }
  }

  Future<List<Enrollment>> fetchStudentEnrollments(String studentId) async {
    try {
      final res = await supabase
          .from('enrollments')
          .select('*, courses(id, name)')
          .eq('student_id', studentId)
          .eq('status', 'active')
          .limit(50);
      return (res as List).map((e) => Enrollment.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchStudentEnrollments failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudentAttendance(
      String studentId) async {
    try {
      final res = await supabase
          .from('attendance')
          .select('*')
          .eq('student_id', studentId)
          .order('attended_at_ts', ascending: false)
          .limit(500);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchStudentAttendance failed: $e');
      rethrow;
    }
  }

  Future<List<EnrollmentHistoryRecord>> fetchEnrollmentHistory(
      String studentId) async {
    try {
      final res = await supabase
          .from('enrollment_history')
          .select(
              'id,student_id,course_id,course_name,purchased_hours,used_hours,price,book_info,receipt_url,renewed_at')
          .eq('student_id', studentId)
          .order('renewed_at', ascending: false)
          .limit(100);
      return (res as List)
          .map((e) => EnrollmentHistoryRecord.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('fetchEnrollmentHistory failed: $e');
      rethrow;
    }
  }

  Future<void> deleteStudent(String id) async {
    try {
      await supabase.from('students').delete().eq('id', id);
    } catch (e) {
      debugPrint('deleteStudent failed: $e');
      rethrow;
    }
  }

  Future<void> updateStudent(
      String id, Map<String, dynamic> updates) async {
    try {
      await supabase.from('students').update(updates).eq('id', id);
    } catch (e) {
      debugPrint('updateStudent failed: $e');
      rethrow;
    }
  }

  // --- Student Notes ---

  Future<List<StudentNote>> fetchStudentNotes(String studentId) async {
    try {
      final res = await supabase
          .from('student_notes')
          .select('*, profiles:created_by(full_name)')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(200);
      return (res as List).map((e) => StudentNote.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchStudentNotes failed: $e');
      rethrow;
    }
  }

  Future<StudentNote> addStudentNote({
    required String studentId,
    required String createdBy,
    required String note,
    String category = 'general',
  }) async {
    try {
      final res = await supabase
          .from('student_notes')
          .insert([
            {
              'student_id': studentId,
              'created_by': createdBy,
              'note': note,
              'category': category,
            }
          ])
          .select('*, profiles:created_by(full_name)')
          .single();
      return StudentNote.fromJson(res);
    } catch (e) {
      debugPrint('addStudentNote failed: $e');
      rethrow;
    }
  }

  Future<void> deleteStudentNote(String noteId) async {
    try {
      await supabase.from('student_notes').delete().eq('id', noteId);
    } catch (e) {
      debugPrint('deleteStudentNote failed: $e');
      rethrow;
    }
  }

  Future<String> uploadStudentPhoto({
    required String studentId,
    required XFile photo,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      final ext = photo.name.split('.').last;
      final path = '$studentId/photo.$ext';
      await supabase.storage.from('student-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl =
          supabase.storage.from('student-photos').getPublicUrl(path);
      await supabase
          .from('students')
          .update({'photo_url': publicUrl}).eq('id', studentId);
      return publicUrl;
    } catch (e) {
      debugPrint('uploadStudentPhoto failed: $e');
      rethrow;
    }
  }

  Future<void> enrollInCourse({
    required String studentId,
    required String courseId,
    required int purchasedHours,
    required Map<String, List<String>> schedule,
  }) async {
    try {
      await supabase.from('enrollments').insert({
        'student_id': studentId,
        'course_id': courseId,
        'purchased_hours': purchasedHours,
        'schedule': schedule,
        'status': 'active',
      });
    } catch (e) {
      debugPrint('enrollInCourse failed: $e');
      rethrow;
    }
  }

  Future<void> addHoursToEnrollment({
    required String enrollmentId,
    required int additionalHours,
  }) async {
    try {
      final current = await supabase
          .from('enrollments')
          .select('purchased_hours')
          .eq('id', enrollmentId)
          .single();
      final currentHours = (current['purchased_hours'] as num?)?.toInt() ?? 0;
      await supabase.from('enrollments').update({
        'purchased_hours': currentHours + additionalHours,
      }).eq('id', enrollmentId);
    } catch (e) {
      debugPrint('addHoursToEnrollment failed: $e');
      rethrow;
    }
  }

  Future<void> cancelEnrollment({
    required String enrollmentId,
    required String cancelledBy,
  }) async {
    try {
      await supabase.from('enrollments').update({
        'status': 'cancelled',
        'cancelled_by': cancelledBy,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', enrollmentId);
    } catch (e) {
      debugPrint('cancelEnrollment failed: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> fetchStudentNameMap(List<String> ids) async {
    try {
      if (ids.isEmpty) return {};
      final res = await supabase
          .from('students')
          .select('id,nick_name,first_name,last_name')
          .inFilter('id', ids)
          .limit(1000);
      final map = <String, String>{};
      for (final s in (res as List)) {
        final nick = s['nick_name'] as String?;
        final first = s['first_name'] as String? ?? '';
        final last = s['last_name'] as String? ?? '';
        map[s['id'] as String] =
            nick != null ? '$nick $first $last' : '$first $last';
      }
      return map;
    } catch (e) {
      debugPrint('fetchStudentNameMap failed: $e');
      rethrow;
    }
  }

  // --- Students with status (3-tab view) ---

  Future<List<StudentWithStatus>> fetchStudentsWithStatus() async {
    try {
      final twoWeeksAgo = DateTime.now()
          .subtract(const Duration(days: 14))
          .toIso8601String();

      final futures = [
        supabase
            .from('students')
            .select(
                'id,first_name,last_name,nick_name,parent_phone,parent_line_id,joined_at,status,qr_code_url,photo_url')
            .or('status.eq.active,status.is.null')
            .order('joined_at', ascending: false)
            .limit(1000),
        supabase
            .from('enrollments')
            .select('student_id, purchased_hours, initial_used_hours, courses(name)')
            .eq('status', 'active')
            .limit(5000),
        supabase
            .from('attendance')
            .select('student_id, attended_at_ts')
            .isFilter('cancelled_by', null)
            .not('approved_by', 'is', null)
            .gte('attended_at_ts', twoWeeksAgo)
            .order('attended_at_ts', ascending: false)
            .limit(5000),
        supabase
            .from('student_course_attendance_summary')
            .select('student_id, total_hours')
            .limit(5000),
        supabase
            .from('line_connections')
            .select('student_id, display_name')
            .limit(5000),
      ];

      final settled = await Future.wait(
        futures.map((f) => f.then<({dynamic data, Object? error})>(
          (data) => (data: data, error: null),
          onError: (Object e) => (data: null, error: e),
        )),
      );

      // Students query is required - if it fails, rethrow
      if (settled[0].error != null) {
        throw settled[0].error!;
      }

      final studentsData = settled[0].data as List;
      final enrollmentsData = settled[1].error == null
          ? settled[1].data as List
          : <dynamic>[];
      final attendanceData = settled[2].error == null
          ? settled[2].data as List
          : <dynamic>[];
      final hourSummaryData = settled[3].error == null
          ? settled[3].data as List
          : <dynamic>[];
      final lineData = settled.length > 4 && settled[4].error == null
          ? settled[4].data as List
          : <dynamic>[];

      final purchasedMap = <String, int>{};
      final initialUsedMap = <String, int>{};
      final courseNamesMap = <String, Set<String>>{};
      for (final e in enrollmentsData) {
        final sid = e['student_id'] as String;
        purchasedMap[sid] =
            (purchasedMap[sid] ?? 0) + ((e['purchased_hours'] as num?)?.toInt() ?? 0);
        initialUsedMap[sid] = (initialUsedMap[sid] ?? 0) +
            ((e['initial_used_hours'] as num?)?.toInt() ?? 0);
        final courses = e['courses'];
        if (courses is Map) {
          final cName = courses['name'] as String?;
          if (cName != null) (courseNamesMap[sid] ??= {}).add(cName);
        }
      }

      final lineNameMap = <String, String>{};
      for (final l in lineData) {
        final sid = l['student_id'] as String?;
        final name = l['display_name'] as String?;
        if (sid != null && name != null) lineNameMap[sid] = name;
      }

      final usedMap = <String, double>{};
      for (final h in hourSummaryData) {
        final sid = h['student_id'] as String;
        usedMap[sid] =
            (usedMap[sid] ?? 0) + ((h['total_hours'] as num?)?.toDouble() ?? 0);
      }

      final lastCheckinMap = <String, String>{};
      for (final a in attendanceData) {
        final sid = a['student_id'] as String;
        lastCheckinMap.putIfAbsent(sid, () => a['attended_at_ts'] as String);
      }

      return studentsData.map((s) {
        final id = s['id'] as String;
        final totalPurchased = purchasedMap[id] ?? 0;
        final totalUsed =
            (usedMap[id] ?? 0) + (initialUsedMap[id] ?? 0);
        final lastCheckin = lastCheckinMap[id];

        String tab = 'active';
        if (totalPurchased > 0 && totalUsed >= totalPurchased) {
          tab = 'finished';
        } else if (lastCheckin == null) {
          tab = 'notActive';
        } else {
          final lastDate = DateTime.tryParse(lastCheckin);
          if (lastDate != null && DateTime.now().difference(lastDate).inDays > 14) {
            tab = 'notActive';
          }
        }

        final student = Student.fromJson(s);
        return StudentWithStatus(
          id: student.id,
          firstName: student.firstName,
          lastName: student.lastName,
          nickName: student.nickName,
          dob: student.dob,
          parentPhone: student.parentPhone,
          parentLineId: student.parentLineId,
          joinedAt: student.joinedAt,
          status: student.status,
          qrCodeUrl: student.qrCodeUrl,
          photoUrl: student.photoUrl,
          lastCheckin: lastCheckin,
          totalPurchased: totalPurchased,
          totalUsed: totalUsed,
          tab: tab,
          lineDisplayName: lineNameMap[id],
          courseNames: (courseNamesMap[id] ?? {}).toList(),
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchStudentsWithStatus failed: $e');
      rethrow;
    }
  }
}
