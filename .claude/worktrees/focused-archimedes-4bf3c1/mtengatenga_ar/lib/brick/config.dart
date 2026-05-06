import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:supabase_flutter/supabase_flutter.dart' as sbf;

import 'brick.g.dart';
import 'db/schema.g.dart';

class BrickConfig {
  static late OfflineFirstWithSupabaseRepository<OfflineFirstWithSupabaseModel>
      repository;

  static Future<void> initialize() async {
    final (_, queue) = OfflineFirstWithSupabaseRepository.clientQueue(
      databaseFactory: databaseFactory,
    );
    final supabaseClient = sbf.Supabase.instance.client;

    repository = _AppBrickRepository(
      supabaseProvider: SupabaseProvider(
        supabaseClient,
        modelDictionary: supabaseModelDictionary,
      ),
      sqliteProvider: SqliteProvider(
        'mtengatenga_museum.sqlite',
        databaseFactory: databaseFactory,
        modelDictionary: sqliteModelDictionary,
      ),
      migrations: migrations,
      offlineRequestQueue: queue,
    );

    await repository.initialize();
  }
}

class _AppBrickRepository
    extends OfflineFirstWithSupabaseRepository<OfflineFirstWithSupabaseModel> {
  _AppBrickRepository({
    required super.supabaseProvider,
    required super.sqliteProvider,
    required super.migrations,
    required super.offlineRequestQueue,
  });
}
