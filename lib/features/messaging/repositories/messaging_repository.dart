import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../models/line_config_model.dart';
import '../models/line_connection_model.dart';
import '../models/unlinked_user_model.dart';

class MessagingRepository {
  Future<LineConfig?> fetchLineConfig() async {
    try {
      final res = await supabase
          .from('line_config')
          .select('*')
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return LineConfig.fromJson(res);
    } catch (e) {
      debugPrint('fetchLineConfig failed: $e');
      rethrow;
    }
  }

  Future<List<LineMessage>> fetchMessages({int limit = 200}) async {
    try {
      final res = await supabase
          .from('line_messages')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).map((e) => LineMessage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchMessages failed: $e');
      rethrow;
    }
  }

  Future<List<LineConnection>> fetchConnections() async {
    try {
      final res = await supabase.from('line_connections').select('*').limit(1000);
      return (res as List).map((e) => LineConnection.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchConnections failed: $e');
      rethrow;
    }
  }

  Future<List<UnlinkedLineUser>> fetchUnlinkedUsers() async {
    try {
      final res = await supabase
          .from('unlinked_line_users')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return (res as List).map((e) => UnlinkedLineUser.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchUnlinkedUsers failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchActiveEnrollments() async {
    try {
      final res = await supabase
          .from('enrollments')
          .select('student_id, course_id')
          .eq('status', 'active')
          .limit(5000);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('fetchActiveEnrollments failed: $e');
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String content,
    required List<String> recipientStudentIds,
    String messageType = 'general',
  }) async {
    try {
      await supabase.rpc('queue_line_message', params: {
        'p_message_type': messageType,
        'p_content': content,
        'p_recipient_student_ids': recipientStudentIds,
      });
    } catch (e) {
      debugPrint('sendMessage failed: $e');
      rethrow;
    }
  }

  Future<void> linkLineAccount({
    required String studentId,
    required String lineUserId,
    String? displayName,
    String? pictureUrl,
    bool sendWelcome = false,
    String? welcomeMessage,
  }) async {
    try {
      await supabase.rpc('link_line_account', params: {
        'p_student_id': studentId,
        'p_line_user_id': lineUserId,
        'p_display_name': displayName,
        'p_picture_url': pictureUrl,
        'p_send_welcome': sendWelcome,
        'p_welcome_message': welcomeMessage,
      });
    } catch (e) {
      debugPrint('linkLineAccount failed: $e');
      rethrow;
    }
  }

  Future<void> unlinkLineAccount(String studentId) async {
    try {
      await supabase
          .from('line_connections')
          .delete()
          .eq('student_id', studentId);
      await supabase
          .from('students')
          .update({'parent_line_id': null}).eq('id', studentId);
    } catch (e) {
      debugPrint('unlinkLineAccount failed: $e');
      rethrow;
    }
  }

  Future<void> updateConnectionDisplayName(
      String connectionId, String name) async {
    try {
      await supabase
          .from('line_connections')
          .update({'display_name': name}).eq('id', connectionId);
    } catch (e) {
      debugPrint('updateConnectionDisplayName failed: $e');
      rethrow;
    }
  }

  Future<void> saveLineConfig({
    String? configId,
    required String channelId,
    String? channelSecret,
    String? channelToken,
  }) async {
    try {
      if (configId != null) {
        await supabase
            .from('line_config')
            .update({'channel_id': channelId}).eq('id', configId);
      } else {
        await supabase
            .from('line_config')
            .insert([{'channel_id': channelId}]);
      }
      if ((channelSecret != null && channelSecret.isNotEmpty) ||
          (channelToken != null && channelToken.isNotEmpty)) {
        await supabase.rpc('save_line_secrets', params: {
          'p_channel_secret': channelSecret,
          'p_channel_token': channelToken,
        });
      }
    } catch (e) {
      debugPrint('saveLineConfig failed: $e');
      rethrow;
    }
  }

  Future<void> toggleAutoNotify(
      String configId, String key, bool value) async {
    try {
      await supabase
          .from('line_config')
          .update({key: value}).eq('id', configId);
    } catch (e) {
      debugPrint('toggleAutoNotify failed: $e');
      rethrow;
    }
  }

  Future<void> saveTemplates(
      String configId, Map<String, dynamic> templates) async {
    try {
      await supabase
          .from('line_config')
          .update({'message_templates': templates}).eq('id', configId);
    } catch (e) {
      debugPrint('saveTemplates failed: $e');
      rethrow;
    }
  }

  Future<String?> uploadPaymentQr(String configId, XFile file) async {
    try {
      final ext = file.name.split('.').last;
      final path = 'payment-qr/$configId.$ext';
      final bytes = await file.readAsBytes();
      await supabase.storage.from('receipts').uploadBinary(path, bytes,
          fileOptions: const FileOptions(upsert: true));
      final publicUrl = supabase.storage.from('receipts').getPublicUrl(path);
      final urlWithBust =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      await supabase
          .from('line_config')
          .update({'payment_qr_url': urlWithBust}).eq('id', configId);
      return urlWithBust;
    } catch (e) {
      debugPrint('uploadPaymentQr failed: $e');
      rethrow;
    }
  }

  Future<void> removePaymentQr(String configId) async {
    try {
      await supabase
          .from('line_config')
          .update({'payment_qr_url': null}).eq('id', configId);
    } catch (e) {
      debugPrint('removePaymentQr failed: $e');
      rethrow;
    }
  }

  Future<LineConnection?> fetchConnectionForStudent(
      String studentId) async {
    try {
      final res = await supabase
          .from('line_connections')
          .select('*')
          .eq('student_id', studentId)
          .maybeSingle();
      if (res == null) return null;
      return LineConnection.fromJson(res);
    } catch (e) {
      debugPrint('fetchConnectionForStudent failed: $e');
      rethrow;
    }
  }
}
