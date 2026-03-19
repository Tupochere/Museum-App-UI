import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/artifact.dart';
import '../../services/supabase_service.dart';
import 'i_artifact_repository.dart';

/// Supabase implementation of artifact repository
class ArtifactRepositorySupabase implements IArtifactRepository {
  final SupabaseService _supabaseService;

  ArtifactRepositorySupabase(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  @override
  Future<List<Artifact>> getAllArtifacts() async {
    try {
      final response = await _client
          .from('artifacts')
          .select()
          .order('updated_at', ascending: false);

      final rows = (response as List)
          .cast<Map<String, dynamic>>();
      return rows.map((json) => Artifact.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load artifacts: $e');
    }
  }

  @override
  Future<Artifact?> getArtifactById(String id) async {
    try {
      final response = await _client
          .from('artifacts')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Artifact.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load artifact $id: $e');
    }
  }

  @override
  Future<List<Artifact>> getArtifactsByRoom(String roomId) async {
    try {
      final response = await _client
          .from('artifacts')
          .select()
          .eq('room_id', roomId)
          .order('name', ascending: true);

      final rows = (response as List)
          .cast<Map<String, dynamic>>();
      return rows.map((json) => Artifact.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load artifacts for room $roomId: $e');
    }
  }
}
