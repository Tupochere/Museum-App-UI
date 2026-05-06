import 'package:brick_core/query.dart';
import 'package:brick_offline_first/brick_offline_first.dart';

import '../../../brick/config.dart';
import '../../domain/entities/room.model.dart';
import '../../domain/repositories/room_repository.dart';
import 'museum_repository.dart';

class RoomRepositoryBrick implements IRoomRepository {
  // ignore: unnecessary_cast
  MuseumRepository get _repository => BrickConfig.repository as MuseumRepository;

  @override
  Future<List<Room>> getAllRooms() {
    return _repository.get<Room>(
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );
  }

  @override
  Future<Room?> getRoomById(String id) async {
    final records = await _repository.get<Room>(
      query: Query(
        where: [Where.exact('id', id)],
        limit: 1,
      ),
      policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );

    if (records.isEmpty) return null;
    return records.first;
  }
}
