import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../models/profile_model.dart';

class AuthRepository {
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await supabase.auth.signInWithPassword(
          email: email, password: password);
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e.message);
      throw Exception(mapped);
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'invalidCredentials';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email not confirmed';
    }
    if (lower.contains('too many requests')) {
      return 'tooManyAttempts';
    }
    return message;
  }

  Future<void> signOut() => supabase.auth.signOut();

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final response = await supabase
        .from('profiles')
        .select('role,school_id,full_name,username,avatar_url')
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  Future<Profile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<String> updateAvatar(String userId, File file) async {
    // Validate file size
    final fileSize = await file.length();
    if (fileSize > AppConstants.maxFileSize) {
      throw Exception('fileTooLarge');
    }

    // Validate file type
    final ext = file.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    if (!allowedExtensions.contains(ext)) {
      throw Exception('invalidFileType');
    }

    final path = '$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('avatars').upload(path, file,
        fileOptions: const FileOptions(upsert: true));
    final avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
    await supabase
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('id', userId);
    return avatarUrl;
  }

  Future<List<Profile>> fetchAllProfiles() async {
    final data = await supabase.rpc('list_all_profiles');
    return (data as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final response = await supabase
        .from('notifications')
        .select('*')
        .eq('read', false)
        .count(CountOption.exact);
    return response.count;
  }

  Future<Map<String, dynamic>?> fetchSchoolTrialStatus(
      String schoolId) async {
    final res = await supabase
        .from('schools')
        .select('status,trial_ends_at,trial_duration,name')
        .eq('id', schoolId)
        .maybeSingle();
    return res;
  }
}
