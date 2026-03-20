// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20260228173234.migration.dart';
part '20260320081229.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{
  const Migration20260228173234(),
  const Migration20260320081229(),
};

/// A consumable database structure including the latest generated migration.
final schema = Schema(
  20260320081229,
  generatorVersion: 1,
  tables: <SchemaTable>{
    SchemaTable(
      '_brick_Artifact_timeline',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn(
          'l_Artifact_brick_id',
          Column.integer,
          isForeignKey: true,
          foreignTableName: 'Artifact',
          onDeleteCascade: true,
          onDeleteSetDefault: false,
        ),
        SchemaColumn(
          'f_TimelineEvent_brick_id',
          Column.integer,
          isForeignKey: true,
          foreignTableName: 'TimelineEvent',
          onDeleteCascade: true,
          onDeleteSetDefault: false,
        ),
      },
      indices: <SchemaIndex>{
        SchemaIndex(
          columns: ['l_Artifact_brick_id', 'f_TimelineEvent_brick_id'],
          unique: true,
        ),
      },
    ),
    SchemaTable(
      'Artifact',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('subtitle', Column.varchar),
        SchemaColumn('category', Column.varchar),
        SchemaColumn('period', Column.varchar),
        SchemaColumn('description', Column.varchar),
        SchemaColumn('cultural_significance', Column.varchar),
        SchemaColumn('additional_notes', Column.varchar),
        SchemaColumn('marker_image_url', Column.varchar),
        SchemaColumn('display_image_url', Column.varchar),
        SchemaColumn('gallery_images', Column.varchar),
        SchemaColumn('audio_url', Column.varchar),
        SchemaColumn('video_urls', Column.varchar),
        SchemaColumn('model3d_url', Column.varchar),
        SchemaColumn('model_thumbnail_url', Column.varchar),
        SchemaColumn('room_id', Column.varchar),
        SchemaColumn('location', Column.varchar),
        SchemaColumn('qr_code', Column.varchar, unique: true),
        SchemaColumn('is_featured', Column.boolean),
        SchemaColumn('ai_context', Column.varchar),
        SchemaColumn('updated_at', Column.datetime),
      },
      indices: <SchemaIndex>{},
    ),
    SchemaTable(
      'TimelineEvent',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('year', Column.varchar),
        SchemaColumn('event', Column.varchar),
        SchemaColumn('artifact_id', Column.varchar),
      },
      indices: <SchemaIndex>{},
    ),
    SchemaTable(
      'Room',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('description', Column.varchar),
      },
      indices: <SchemaIndex>{},
    ),
  },
);
