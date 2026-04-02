import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/profile.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Sign up with email, password, and full name.
  /// The full_name is passed as user metadata so the database trigger
  /// can populate the profiles table automatically.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() => _client.auth.signOut();

  /// Send a password reset email.
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// The currently signed-in Supabase user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign in, sign out, token refresh).
  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Fetch the profile for the current user from the profiles table.
  Future<Profile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return null;
      return Profile.fromMap(row);
    } catch (e) {
      debugPrint('AuthService.getProfile error: $e');
      return null;
    }
  }

  /// Update the current user's profile.
  Future<void> updateProfile({String? fullName}) async {
    final user = currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }
}
