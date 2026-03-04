// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260228173234_up = [
  InsertTable('_brick_Artifact_timeline'),
  InsertTable('Artifact'),
  InsertTable('TimelineEvent'),
  InsertTable('Room'),
  InsertForeignKey('_brick_Artifact_timeline', 'Artifact', foreignKeyColumn: 'l_Artifact_brick_id', onDeleteCascade: true, onDeleteSetDefault: false),
  InsertForeignKey('_brick_Artifact_timeline', 'TimelineEvent', foreignKeyColumn: 'f_TimelineEvent_brick_id', onDeleteCascade: true, onDeleteSetDefault: false),
  InsertColumn('id', Column.varchar, onTable: 'Artifact', unique: true),
  InsertColumn('name', Column.varchar, onTable: 'Artifact'),
  InsertColumn('subtitle', Column.varchar, onTable: 'Artifact'),
  InsertColumn('category', Column.varchar, onTable: 'Artifact'),
  InsertColumn('period', Column.varchar, onTable: 'Artifact'),
  InsertColumn('description', Column.varchar, onTable: 'Artifact'),
  InsertColumn('cultural_significance', Column.varchar, onTable: 'Artifact'),
  InsertColumn('additional_notes', Column.varchar, onTable: 'Artifact'),
  InsertColumn('marker_image_url', Column.varchar, onTable: 'Artifact'),
  InsertColumn('display_image_url', Column.varchar, onTable: 'Artifact'),
  InsertColumn('gallery_images', Column.varchar, onTable: 'Artifact'),
  InsertColumn('audio_url', Column.varchar, onTable: 'Artifact'),
  InsertColumn('video_urls', Column.varchar, onTable: 'Artifact'),
  InsertColumn('model3d_url', Column.varchar, onTable: 'Artifact'),
  InsertColumn('model_thumbnail_url', Column.varchar, onTable: 'Artifact'),
  InsertColumn('room_id', Column.varchar, onTable: 'Artifact'),
  InsertColumn('location', Column.varchar, onTable: 'Artifact'),
  InsertColumn('qr_code', Column.varchar, onTable: 'Artifact', unique: true),
  InsertColumn('is_featured', Column.boolean, onTable: 'Artifact'),
  InsertColumn('updated_at', Column.datetime, onTable: 'Artifact'),
  InsertColumn('id', Column.varchar, onTable: 'TimelineEvent', unique: true),
  InsertColumn('year', Column.varchar, onTable: 'TimelineEvent'),
  InsertColumn('event', Column.varchar, onTable: 'TimelineEvent'),
  InsertColumn('artifact_id', Column.varchar, onTable: 'TimelineEvent'),
  InsertColumn('id', Column.varchar, onTable: 'Room', unique: true),
  InsertColumn('name', Column.varchar, onTable: 'Room'),
  InsertColumn('description', Column.varchar, onTable: 'Room'),
  InsertColumn('image_url', Column.varchar, onTable: 'Room'),
  InsertColumn('floor_level', Column.integer, onTable: 'Room'),
  InsertColumn('display_order', Column.integer, onTable: 'Room'),
  CreateIndex(columns: ['l_Artifact_brick_id', 'f_TimelineEvent_brick_id'], onTable: '_brick_Artifact_timeline', unique: true)
];

const List<MigrationCommand> _migration_20260228173234_down = [
  DropTable('_brick_Artifact_timeline'),
  DropTable('Artifact'),
  DropTable('TimelineEvent'),
  DropTable('Room'),
  DropColumn('l_Artifact_brick_id', onTable: '_brick_Artifact_timeline'),
  DropColumn('f_TimelineEvent_brick_id', onTable: '_brick_Artifact_timeline'),
  DropColumn('id', onTable: 'Artifact'),
  DropColumn('name', onTable: 'Artifact'),
  DropColumn('subtitle', onTable: 'Artifact'),
  DropColumn('category', onTable: 'Artifact'),
  DropColumn('period', onTable: 'Artifact'),
  DropColumn('description', onTable: 'Artifact'),
  DropColumn('cultural_significance', onTable: 'Artifact'),
  DropColumn('additional_notes', onTable: 'Artifact'),
  DropColumn('marker_image_url', onTable: 'Artifact'),
  DropColumn('display_image_url', onTable: 'Artifact'),
  DropColumn('gallery_images', onTable: 'Artifact'),
  DropColumn('audio_url', onTable: 'Artifact'),
  DropColumn('video_urls', onTable: 'Artifact'),
  DropColumn('model3d_url', onTable: 'Artifact'),
  DropColumn('model_thumbnail_url', onTable: 'Artifact'),
  DropColumn('room_id', onTable: 'Artifact'),
  DropColumn('location', onTable: 'Artifact'),
  DropColumn('qr_code', onTable: 'Artifact'),
  DropColumn('is_featured', onTable: 'Artifact'),
  DropColumn('updated_at', onTable: 'Artifact'),
  DropColumn('id', onTable: 'TimelineEvent'),
  DropColumn('year', onTable: 'TimelineEvent'),
  DropColumn('event', onTable: 'TimelineEvent'),
  DropColumn('artifact_id', onTable: 'TimelineEvent'),
  DropColumn('id', onTable: 'Room'),
  DropColumn('name', onTable: 'Room'),
  DropColumn('description', onTable: 'Room'),
  DropColumn('image_url', onTable: 'Room'),
  DropColumn('floor_level', onTable: 'Room'),
  DropColumn('display_order', onTable: 'Room'),
  DropIndex('index__brick_Artifact_timeline_on_l_Artifact_brick_id_f_TimelineEvent_brick_id')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260228173234',
  up: _migration_20260228173234_up,
  down: _migration_20260228173234_down,
)
class Migration20260228173234 extends Migration {
  const Migration20260228173234()
    : super(
        version: 20260228173234,
        up: _migration_20260228173234_up,
        down: _migration_20260228173234_down,
      );
}
