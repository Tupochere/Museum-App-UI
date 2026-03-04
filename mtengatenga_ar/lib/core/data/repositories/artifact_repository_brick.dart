import 'package:brick_core/query.dart';
import 'package:brick_offline_first/brick_offline_first.dart';

import '../../../brick/config.dart';
import '../../domain/entities/artifact.model.dart';
import '../../domain/repositories/artifact_repository.dart';
import 'museum_repository.dart';

class ArtifactRepositoryBrick implements IArtifactRepository {
  // ignore: unnecessary_cast
  MuseumRepository get _repository => BrickConfig.repository as MuseumRepository;

  @override
  Future<List<Artifact>> getAllArtifacts() {
    return _repository.get<Artifact>(
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );
  }

  @override
  Future<Artifact?> getArtifactById(String id) async {
    final records = await _repository.get<Artifact>(
      query: Query(
        where: [Where.exact('id', id)],
        limit: 1,
      ),
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );

    if (records.isEmpty) return null;
    return records.first;
  }

  @override
  Future<List<Artifact>> getArtifactsByRoom(String roomId) {
    return _repository.get<Artifact>(
      query: Query(
        where: [Where.exact('roomId', roomId)],
      ),
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );
  }

  @override
  Future<Artifact?> getArtifactByQrCode(String qrCode) async {
    final records = await _repository.get<Artifact>(
      query: Query(
        where: [Where.exact('qrCode', qrCode)],
        limit: 1,
      ),
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );

    if (records.isEmpty) return null;
    return records.first;
  }

  @override
  Future<List<Artifact>> getFeaturedArtifacts() {
    return _repository.get<Artifact>(
      query: Query(
        where: [Where.exact('isFeatured', true)],
      ),
      policy: OfflineFirstGetPolicy.localOnly,
    );
  }
}
