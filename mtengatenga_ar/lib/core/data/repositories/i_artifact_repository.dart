import '../../domain/entities/artifact.dart';

/// Repository interface (contract) for artifact data access.
/// Implementations can use Supabase, local DB, or both.
abstract class IArtifactRepository {
  /// Fetch all artifacts from the data source
  Future<List<Artifact>> getAllArtifacts();

  /// Fetch a single artifact by ID
  Future<Artifact?> getArtifactById(String id);

  /// Get artifacts for a specific room
  Future<List<Artifact>> getArtifactsByRoom(String roomId);
}
