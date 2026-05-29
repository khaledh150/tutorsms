import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../models/application_change_model.dart';
import '../models/application_model.dart';

class ApplicationRepository {
  Future<List<Application>> fetchPendingApplications() async {
    try {
      final res = await supabase
          .from('applications')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(500);
      return (res as List).map((e) => Application.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchPendingApplications failed: $e');
      rethrow;
    }
  }

  Future<List<ApplicationChange>> fetchPendingChanges() async {
    try {
      final res = await supabase
          .from('application_changes')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(500);
      return (res as List)
          .map((e) => ApplicationChange.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('fetchPendingChanges failed: $e');
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

  Future<void> approveApplications(List<String> ids) async {
    try {
      await supabase
          .from('applications')
          .update({'status': 'approved'})
          .inFilter('id', ids);
    } catch (e) {
      debugPrint('approveApplications failed: $e');
      rethrow;
    }
  }

  Future<void> approveChanges(List<String> ids) async {
    try {
      await supabase
          .from('application_changes')
          .update({
            'status': 'approved',
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', ids);
    } catch (e) {
      debugPrint('approveChanges failed: $e');
      rethrow;
    }
  }

  Future<void> rejectApplications(List<String> ids) async {
    try {
      await supabase.from('applications').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('rejectApplications failed: $e');
      rethrow;
    }
  }

  Future<void> rejectChanges(List<String> ids) async {
    try {
      await supabase
          .from('application_changes')
          .delete()
          .inFilter('id', ids);
    } catch (e) {
      debugPrint('rejectChanges failed: $e');
      rethrow;
    }
  }

  Future<List<ApplicationChange>> fetchPendingChangesForStudent(
      String studentId) async {
    try {
      final res = await supabase
          .from('application_changes')
          .select('*')
          .eq('student_id', studentId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List)
          .map((e) => ApplicationChange.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('fetchPendingChangesForStudent failed: $e');
      rethrow;
    }
  }

  Future<void> submitApplication({
    required String nickName,
    required String firstName,
    required String lastName,
    String? dob,
    required String parentPhone,
    String? parentLineId,
    required Map<String, dynamic> courses,
    required Map<String, int> courseLimits,
    required List<String> paymentReceiptUrls,
    String? submittedBy,
  }) async {
    try {
      await supabase.from('applications').insert([
        {
          'nick_name': nickName,
          'first_name': firstName,
          'last_name': lastName,
          'dob': dob,
          'parent_phone': parentPhone,
          'parent_line_id': parentLineId,
          'courses': courses,
          'course_limits': courseLimits,
          'payment_receipt_urls': paymentReceiptUrls,
          'status': 'pending',
        }
      ]);
    } catch (e) {
      debugPrint('submitApplication failed: $e');
      rethrow;
    }
  }

  Future<String?> directEnrollStudent({
    required String nickName,
    required String firstName,
    required String lastName,
    String? dob,
    required String parentPhone,
    String? parentLineId,
    required Map<String, dynamic> courses,
    required Map<String, int> courseLimits,
    required List<String> paymentReceiptUrls,
    required List<Map<String, dynamic>> enrollmentRows,
    XFile? studentPhoto,
    List<Map<String, dynamic>>? purchasedPackages,
    int? totalPrice,
  }) async {
    try {
      final res = await supabase
          .from('students')
          .insert([
            {
              'nick_name': nickName,
              'first_name': firstName,
              'last_name': lastName,
              'dob': dob,
              'parent_phone': parentPhone,
              'parent_line_id': parentLineId,
              'courses': courses,
              'course_limits': courseLimits,
              'payment_receipt_urls': paymentReceiptUrls,
              'joined_at': DateTime.now().toIso8601String(),
              'status': 'active',
              'purchased_packages': ?purchasedPackages,
              'total_price': ?totalPrice,
            }
          ])
          .select()
          .single();

      final studentId = res['id'] as String;

      if (studentPhoto != null) {
        final ext = studentPhoto.name.split('.').last;
        final photoPath = '$studentId.$ext';
        final bytes = await studentPhoto.readAsBytes();
        await supabase.storage
            .from('student-photos')
            .uploadBinary(photoPath, bytes, fileOptions: const FileOptions(upsert: true));
        final publicUrl =
            supabase.storage.from('student-photos').getPublicUrl(photoPath);
        final urlWithBust =
            '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        await supabase
            .from('students')
            .update({'photo_url': urlWithBust})
            .eq('id', studentId);
      }

      if (enrollmentRows.isNotEmpty) {
        final rows = enrollmentRows
            .map((r) => {...r, 'student_id': studentId})
            .toList();
        await supabase.from('enrollments').insert(rows);
      }

      await supabase.from('notifications').insert([
        {
          'type': 'new_application',
          'student_id': studentId,
          'payload': {
            'name': nickName,
            'first_name': firstName,
            'student_name': nickName,
          },
          'read': false,
        }
      ]);

      return studentId;
    } catch (e) {
      debugPrint('directEnrollStudent failed: $e');
      rethrow;
    }
  }

  Future<void> submitChangeRequest({
    required String studentId,
    required String type,
    required Map<String, dynamic> changes,
    List<String>? receiptUrls,
  }) async {
    try {
      await supabase.from('application_changes').insert([
        {
          'student_id': studentId,
          'type': type,
          'changes': changes,
          'receipt_urls': receiptUrls,
          'status': 'pending',
        }
      ]);
    } catch (e) {
      debugPrint('submitChangeRequest failed: $e');
      rethrow;
    }
  }

  Future<List<String>> uploadReceipts(List<XFile> files) async {
    try {
      final urls = <String>[];
      final rng = Random();
      for (final f in files) {
        final ext = f.name.split('.').last;
        final fn =
            '${DateTime.now().millisecondsSinceEpoch}-${rng.nextInt(999999).toRadixString(36)}.$ext';
        final bytes = await f.readAsBytes();
        final uploadRes = await supabase.storage
            .from('receipts')
            .uploadBinary(fn, bytes, fileOptions: const FileOptions(cacheControl: '3600'));
        final publicUrl =
            supabase.storage.from('receipts').getPublicUrl(uploadRes);
        urls.add(publicUrl);
      }
      return urls;
    } catch (e) {
      debugPrint('uploadReceipts failed: $e');
      rethrow;
    }
  }
}
