import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'rooms'),
)
class Room extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String name;

  final String? description;

  Room({required this.id, required this.name, this.description});
}
