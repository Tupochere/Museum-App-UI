import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/profile.dart';
import 'auth_service.dart';
import 'saved_artifacts_service.dart';
import '../../services/push_notification_service.dart';

/// Reactive auth state that the UI listens to via ListenableBuilder.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._authService) {
    _subscription = _authService.onAuthStateChange.listen(_onAuthEvent);
    // Check for an existing persisted session on startup.
    _checkInitialSession();
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;

  User? _user;
  Profile? _profile;
  bool _isLoading = true;

  User? get user => _user;
  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  void _checkInitialSession() {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _user = currentUser;
      _fetchProfile();
    }
    _isLoading = false;
    notifyListeners();
  }

  void _onAuthEvent(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        _user = state.session?.user;
        _fetchProfile();
        _linkDeviceToken();
        _loadSavedArtifacts();
        notifyListeners();
        break;
      case AuthChangeEvent.signedOut:
        _user = null;
        _profile = null;
        _clearSavedArtifacts();
        notifyListeners();
        break;
      default:
        break;
    }
  }

  Future<void> _fetchProfile() async {
    _profile = await _authService.getProfile();
    notifyListeners();
  }

  void _linkDeviceToken() {
    try {
      GetIt.instance<PushNotificationService>().linkCurrentUser();
    } catch (e) {
      debugPrint('Failed to link device token: $e');
    }
  }

  void _loadSavedArtifacts() {
    try {
      GetIt.instance<SavedArtifactsService>().load();
    } catch (e) {
      debugPrint('Failed to load saved artifacts: $e');
    }
  }

  void _clearSavedArtifacts() {
    try {
      GetIt.instance<SavedArtifactsService>().value = {};
    } catch (e) {
      debugPrint('Failed to clear saved artifacts: $e');
    }
  }

  /// Refresh the cached profile (e.g. after an edit).
  Future<void> refreshProfile() async {
    await _fetchProfile();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
