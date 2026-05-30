import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

class RenewalData {
  final String studentName;
  final String courseName;
  final List<Map<String, dynamic>> packages;
  final String? qrUrl;
  final int usedHours;
  final int purchasedHours;
  final String schoolId;
  final String studentId;
  final String courseId;

  const RenewalData({
    required this.studentName,
    required this.courseName,
    required this.packages,
    this.qrUrl,
    required this.usedHours,
    required this.purchasedHours,
    required this.schoolId,
    required this.studentId,
    required this.courseId,
  });

  int get remaining => purchasedHours - usedHours;
}

class RenewalRepository {
  Future<Map<String, dynamic>> validateRenewalToken(
    String token,
    String studentId,
    String courseId,
  ) async {
    final res = await supabase
        .from('renewal_tokens')
        .select('*')
        .eq('token', token)
        .eq('student_id', studentId)
        .eq('course_id', courseId)
        .isFilter('used_at', null)
        .gt('expires_at', DateTime.now().toIso8601String())
        .single();
    return res;
  }

  Future<RenewalData> fetchRenewalData(
    Map<String, dynamic> tokenRow,
    String studentId,
    String courseId,
  ) async {
    final schoolId = tokenRow['school_id'] as String;

    final results = await Future.wait([
      supabase
          .from('students')
          .select('nick_name,first_name,last_name')
          .eq('id', studentId)
          .single(),
      supabase
          .from('courses')
          .select('name,hour_packages')
          .eq('id', courseId)
          .single(),
      supabase
          .from('enrollments')
          .select('purchased_hours,initial_used_hours')
          .eq('student_id', studentId)
          .eq('course_id', courseId)
          .single(),
      supabase
          .from('line_config')
          .select('payment_qr_url')
          .eq('school_id', schoolId)
          .maybeSingle(),
    ]);

    final student = results[0] as Map<String, dynamic>;
    final course = results[1] as Map<String, dynamic>;
    final enrollment = results[2] as Map<String, dynamic>;
    final config = results[3];

    final countRes = await supabase
        .from('attendance')
        .select('id')
        .eq('student_id', studentId)
        .eq('course_id', courseId)
        .not('approved_by', 'is', null)
        .isFilter('cancelled_by', null)
        .count(CountOption.exact);
    final usedHours =
        countRes.count + ((enrollment['initial_used_hours'] as num?)?.toInt() ?? 0);

    final nickName = student['nick_name'] as String?;
    final firstName = student['first_name'] as String;
    final displayName =
        nickName != null ? '$nickName $firstName' : firstName;

    final rawPackages = course['hour_packages'];
    final packages = <Map<String, dynamic>>[];
    if (rawPackages is List) {
      for (final p in rawPackages) {
        if (p is Map) packages.add(Map<String, dynamic>.from(p));
      }
    }

    return RenewalData(
      studentName: displayName,
      courseName: course['name'] as String,
      packages: packages,
      qrUrl: config?['payment_qr_url'] as String?,
      usedHours: usedHours,
      purchasedHours:
          (enrollment['purchased_hours'] as num?)?.toInt() ?? 0,
      schoolId: schoolId,
      studentId: studentId,
      courseId: courseId,
    );
  }

  Future<void> submitRenewalSlip({
    required String schoolId,
    required String studentId,
    required String courseId,
    required String courseName,
    required int selectedHours,
    required int selectedPrice,
    required XFile file,
    required String token,
  }) async {
    final path = '$schoolId/renewal-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await file.readAsBytes();
    await supabase.storage
        .from('receipts')
        .uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'));

    final urlData =
        supabase.storage.from('receipts').getPublicUrl(path);

    await supabase.from('application_changes').insert({
      'student_id': studentId,
      'type': 'renewal',
      'status': 'pending',
      'changes': {
        'course_limits': {courseId: selectedHours}
      },
      'receipt_urls': [urlData],
      'purchased_packages': [
        {
          'course_id': courseId,
          'course_name': courseName,
          'hours': selectedHours,
          'price': selectedPrice,
        }
      ],
      'total_price': selectedPrice,
      'school_id': schoolId,
    });

    await supabase
        .from('renewal_tokens')
        .update({'used_at': DateTime.now().toIso8601String()})
        .eq('token', token);
  }
}
