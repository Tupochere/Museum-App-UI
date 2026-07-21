import '../entities/artifact.model.dart';

abstract class IArtifactRepository {
  Future<List<Artifact>> getAllArtifacts();
  Future<Artifact?> getArtifactById(String id);
  Future<List<Artifact>> getArtifactsByRoom(String roomId);
  Future<Artifact?> getArtifactByQrCode(String qrCode);
  Future<List<Artifact>> getFeaturedArtifacts();
}
