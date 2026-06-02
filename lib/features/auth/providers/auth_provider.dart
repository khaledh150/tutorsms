import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

/// Holds trial status for the current user's school.
class TrialStatus {
  final bool isExpired;
  final String? trialDuration;
  final String? trialEndsAt;
  final String? schoolName;

  const TrialStatus({
    this.isExpired = false,
    this.trialDuration,
    this.trialEndsAt,
    this.schoolName,
  });
}

final trialStatusProvider = StateProvider<TrialStatus>((_) => const TrialStatus());

class AuthNotifier extends AsyncNotifier<AppUser?> {
  late final AuthRepository _repo;
  StreamSubscription<AuthState>? _authSub;

  @override
  Future<AppUser?> build() async {
    _repo = ref.read(authRepositoryProvider);

    _authSub?.cancel();
    _authSub = _repo.authStateChanges.listen(_onAuthStateChange);

    ref.onDispose(() {
      _authSub?.cancel();
    });

    final user = _repo.currentUser;
    if (user == null) return null;

    return _loadProfile(user.id, user.email);
  }

  void _onAuthStateChange(AuthState authState) {
    final session = authState.session;

    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        if (session?.user != null) {
          _loadProfileAndUpdate(session!.user.id, session.user.email);
        }
      case AuthChangeEvent.signedOut:
        state = const AsyncData(null);
      case AuthChangeEvent.tokenRefreshed:
        break;
      default:
        break;
    }
  }

  Future<AppUser?> _loadProfile(String id, String? email) async {
    final profile = await _repo.fetchProfile(id);
    if (profile == null) {
      return AppUser(id: id, email: email);
    }
    final appUser = AppUser.fromProfile(id, email, profile);

    // Check trial status for non-superadmin users
    if (!appUser.isSuperAdmin && appUser.schoolId != null) {
      try {
        final trial = await _repo.fetchSchoolTrialStatus(appUser.schoolId!);
        if (trial != null) {
          final status = trial['status'] as String?;
          final trialEndsAt = trial['trial_ends_at'] as String?;
          final trialDuration = trial['trial_duration'] as String?;
          final schoolName = trial['name'] as String? ?? '';

          final trialEnd = trialEndsAt != null ? DateTime.tryParse(trialEndsAt) : null;
          final isExpired = status == 'free' &&
              trialEnd != null &&
              DateTime.now().isAfter(trialEnd);

          ref.read(trialStatusProvider.notifier).state = TrialStatus(
            isExpired: isExpired,
            trialDuration: trialDuration,
            trialEndsAt: trialEndsAt,
            schoolName: schoolName,
          );
        }
      } catch (_) {
        // Trial check is non-critical
      }
    }

    return appUser;
  }

  Future<void> _loadProfileAndUpdate(String id, String? email) async {
    state = const AsyncLoading();
    state = AsyncData(await _loadProfile(id, email));
  }

  Future<void> signIn(String email, String password) async {
    var loginEmail = email.trim().toLowerCase();
    if (!loginEmail.contains('@')) {
      loginEmail += '@${AppConstants.schoolDomain}';
    }
    await _repo.signIn(loginEmail, password.trim());
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(null);
  }
}
