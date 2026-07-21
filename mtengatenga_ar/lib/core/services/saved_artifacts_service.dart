import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the current user's saved/bookmarked artifacts.
/// Exposes a [ValueListenable<Set<String>>] of saved artifact IDs so widgets
/// can reactively update heart icons.
class SavedArtifactsService extends ValueNotifier<Set<String>> {
  SavedArtifactsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        super({});

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Loads the full set of saved artifact IDs for the current user.
  Future<void> load() async {
    if (_userId == null) return;
    try {
      final rows = await _client
          .from('saved_artifacts')
          .select('artifact_id')
          .eq('user_id', _userId!);
      value = {
        for (final row in rows) row['artifact_id'] as String,
      };
    } catch (e) {
      debugPrint('SavedArtifactsService.load failed: $e');
    }
  }

  bool isSaved(String artifactId) => value.contains(artifactId);

  /// Toggles the saved state for [artifactId].
  /// Returns the new saved state.
  Future<bool> toggle(String artifactId) async {
    if (_userId == null) return false;

    if (isSaved(artifactId)) {
      return _unsave(artifactId);
    } else {
      return _save(artifactId);
    }
  }

  Future<bool> _save(String artifactId) async {
    // Optimistic update
    value = {...value, artifactId};
    try {
      await _client.from('saved_artifacts').insert({
        'user_id': _userId!,
        'artifact_id': artifactId,
      });
      return true;
    } catch (e) {
      // Rollback
      value = {...value}..remove(artifactId);
      debugPrint('SavedArtifactsService.save failed: $e');
      return false;
    }
  }

  Future<bool> _unsave(String artifactId) async {
    // Optimistic update
    value = {...value}..remove(artifactId);
    try {
      await _client
          .from('saved_artifacts')
          .delete()
          .eq('user_id', _userId!)
          .eq('artifact_id', artifactId);
      return false;
    } catch (e) {
      // Rollback
      value = {...value, artifactId};
      debugPrint('SavedArtifactsService.unsave failed: $e');
      return true;
    }
  }

  /// Returns full artifact rows for all saved IDs by joining with the
  /// artifacts table. Used by the Saved Artifacts screen.
  Future<List<Map<String, dynamic>>> getSavedArtifacts() async {
    if (_userId == null || value.isEmpty) return [];
    try {
      final ids = value.toList();
      final rows = await _client
          .from('artifacts')
          .select('id, name, subtitle, period, category, display_image_url')
          .inFilter('id', ids);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('SavedArtifactsService.getSavedArtifacts failed: $e');
      return [];
    }
  }
}
