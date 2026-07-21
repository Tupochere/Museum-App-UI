// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<TimelineEvent> _$TimelineEventFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return TimelineEvent(
    id: data['id'] == null ? null : data['id'] as String?,
    year: data['year'] as String,
    event: data['event'] as String,
    artifactId: data['artifact_id'] == null
        ? null
        : data['artifact_id'] as String?,
  );
}

Future<Map<String, dynamic>> _$TimelineEventToSupabase(
  TimelineEvent instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'year': instance.year,
    'event': instance.event,
    'artifact_id': instance.artifactId,
  };
}

Future<TimelineEvent> _$TimelineEventFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return TimelineEvent(
    id: data['id'] == null ? null : data['id'] as String?,
    year: data['year'] as String,
    event: data['event'] as String,
    artifactId: data['artifact_id'] == null
        ? null
        : data['artifact_id'] as String?,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$TimelineEventToSqlite(
  TimelineEvent instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'year': instance.year,
    'event': instance.event,
    'artifact_id': instance.artifactId,
  };
}

/// Construct a [TimelineEvent]
class TimelineEventAdapter
    extends OfflineFirstWithSupabaseAdapter<TimelineEvent> {
  TimelineEventAdapter();

  @override
  final supabaseTableName = 'timeline_events';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'year': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'year',
    ),
    'event': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'event',
    ),
    'artifactId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'artifact_id',
    ),
  };
  @override
  final ignoreDuplicates = false;
  @override
  final uniqueFields = {'id'};
  @override
  final Map<String, RuntimeSqliteColumnDefinition> fieldsToSqliteColumns = {
    'primaryKey': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: '_brick_id',
      iterable: false,
      type: int,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    ),
    'year': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'year',
      iterable: false,
      type: String,
    ),
    'event': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'event',
      iterable: false,
      type: String,
    ),
    'artifactId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'artifact_id',
      iterable: false,
      type: String,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    TimelineEvent instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `TimelineEvent` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'TimelineEvent';

  @override
  Future<TimelineEvent> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$TimelineEventFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    TimelineEvent input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$TimelineEventToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<TimelineEvent> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$TimelineEventFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    TimelineEvent input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$TimelineEventToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
