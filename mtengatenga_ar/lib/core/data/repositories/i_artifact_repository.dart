import '../../domain/entities/artifact.dart';

// @codex: Repository contract for artifact data access.
// Keep widget and service layers dependent on this abstraction, not Supabase details.
// Add new artifact read/write methods here first, then implement them in data sources.
abstract class IArtifactRepository {
  Future<List<Artifact>> getAllArtifacts();
  Future<Artifact?> getArtifactById(String id);
  Future<List<Artifact>> getArtifactsByRoom(String roomId);
  Future<Artifact?> getArtifactByQrCode(String qrCode);
  Future<List<Artifact>> getFeaturedArtifacts();
}
