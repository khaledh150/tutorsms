import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_client.dart';

class OfflineCheckinQueue {
  static const _key = 'offline_checkin_queue';
  static final OfflineCheckinQueue instance = OfflineCheckinQueue._();
  OfflineCheckinQueue._();

  final ValueNotifier<int> queueCount = ValueNotifier(0);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    queueCount.value = list.length;

    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncQueue();
    });
  }

  Future<void> enqueue({
    required String studentId,
    required String courseId,
    required String approverId,
    int hours = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode({
      'student_id': studentId,
      'course_id': courseId,
      'approver_id': approverId,
      'hours': hours,
      'ts': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_key, list);
    queueCount.value = list.length;
  }

  Future<int> syncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (list.isEmpty) return 0;

    int synced = 0;
    final remaining = <String>[];

    for (final item in list) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final ts = data['ts'] as String;
        final hours = (data['hours'] as num?)?.toInt() ?? 1;
        final inserts = List.generate(hours, (_) => <String, dynamic>{
          'student_id': data['student_id'],
          'course_id': data['course_id'],
          'attended_at_ts': ts,
          'approved_by': data['approver_id'],
        });
        await supabase.from('attendance').insert(inserts);
        synced++;
      } catch (e) {
        remaining.add(item);
        debugPrint('Offline sync failed for item: $e');
      }
    }

    await prefs.setStringList(_key, remaining);
    queueCount.value = remaining.length;
    return synced;
  }
}
