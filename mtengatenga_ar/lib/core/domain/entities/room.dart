import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';

part 'room.g.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'rooms'),
)
class Room extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String name;

  final String? description;

  @Supabase(name: 'image_url')
  @Sqlite(name: 'image_url')
  final String? imageUrl;

  @Supabase(name: 'floor_level')
  @Sqlite(name: 'floor_level')
  final int? floorLevel;

  @Supabase(name: 'display_order')
  @Sqlite(name: 'display_order')
  final int? displayOrder;

  const Room({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.floorLevel,
    this.displayOrder,
  });
}
