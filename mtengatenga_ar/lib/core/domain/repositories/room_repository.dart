import '../entities/room.model.dart';

abstract class IRoomRepository {
  Future<List<Room>> getAllRooms();
  Future<Room?> getRoomById(String id);
}
