// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<Artifact> _$ArtifactFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Artifact(
    id: data['id'] as String,
    name: data['name'] as String,
    subtitle: data['subtitle'] == null ? null : data['subtitle'] as String?,
    category: data['category'] == null ? null : data['category'] as String?,
    period: data['period'] == null ? null : data['period'] as String?,
    description: data['description'] as String,
    culturalSignificance: data['cultural_significance'] == null
        ? null
        : data['cultural_significance'] as String?,
    additionalNotes: data['additional_notes'] == null
        ? null
        : data['additional_notes'] as String?,
    timeline: data['timeline'] == null
        ? null
        : await Future.wait<TimelineEvent>(
            data['timeline']
                    ?.map(
                      (d) => TimelineEventAdapter().fromSupabase(
                        d,
                        provider: provider,
                        repository: repository,
                      ),
                    )
                    .toList()
                    .cast<Future<TimelineEvent>>() ??
                [],
          ),
    markerImageUrl: data['marker_image_url'] == null
        ? null
        : data['marker_image_url'] as String?,
    displayImageUrl: data['display_image_url'] == null
        ? null
        : data['display_image_url'] as String?,
    galleryImages: data['gallery_images'] == null
        ? null
        : data['gallery_images']?.toList().cast<String>(),
    audioUrl: data['audio_url'] == null ? null : data['audio_url'] as String?,
    videoUrls: data['video_urls'] == null
        ? null
        : data['video_urls']?.toList().cast<String>(),
    model3dUrl: data['model_3d_url'] == null
        ? null
        : data['model_3d_url'] as String?,
    modelThumbnailUrl: data['model_thumbnail_url'] == null
        ? null
        : data['model_thumbnail_url'] as String?,
    roomId: data['room_id'] == null ? null : data['room_id'] as String?,
    location: data['location'] == null ? null : data['location'] as String?,
    qrCode: data['qr_code'] == null ? null : data['qr_code'] as String?,
    isFeatured: data['is_featured'] as bool,
    aiContext: data['ai_context'] == null
        ? null
        : data['ai_context'] as String?,
    updatedAt: DateTime.parse(data['updated_at'] as String),
  );
}

Future<Map<String, dynamic>> _$ArtifactToSupabase(
  Artifact instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'name': instance.name,
    'subtitle': instance.subtitle,
    'category': instance.category,
    'period': instance.period,
    'description': instance.description,
    'cultural_significance': instance.culturalSignificance,
    'additional_notes': instance.additionalNotes,
    'timeline': await Future.wait<Map<String, dynamic>>(
      instance.timeline
              ?.map(
                (s) => TimelineEventAdapter().toSupabase(
                  s,
                  provider: provider,
                  repository: repository,
                ),
              )
              .toList() ??
          [],
    ),
    'marker_image_url': instance.markerImageUrl,
    'display_image_url': instance.displayImageUrl,
    'gallery_images': instance.galleryImages,
    'audio_url': instance.audioUrl,
    'video_urls': instance.videoUrls,
    'model_3d_url': instance.model3dUrl,
    'model_thumbnail_url': instance.modelThumbnailUrl,
    'room_id': instance.roomId,
    'location': instance.location,
    'qr_code': instance.qrCode,
    'is_featured': instance.isFeatured,
    'ai_context': instance.aiContext,
    'updated_at': instance.updatedAt.toIso8601String(),
  };
}

Future<Artifact> _$ArtifactFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Artifact(
    id: data['id'] as String,
    name: data['name'] as String,
    subtitle: data['subtitle'] == null ? null : data['subtitle'] as String?,
    category: data['category'] == null ? null : data['category'] as String?,
    period: data['period'] == null ? null : data['period'] as String?,
    description: data['description'] as String,
    culturalSignificance: data['cultural_significance'] == null
        ? null
        : data['cultural_significance'] as String?,
    additionalNotes: data['additional_notes'] == null
        ? null
        : data['additional_notes'] as String?,
    timeline:
        (await provider
                .rawQuery(
                  'SELECT DISTINCT `f_TimelineEvent_brick_id` FROM `_brick_Artifact_timeline` WHERE l_Artifact_brick_id = ?',
                  [data['_brick_id'] as int],
                )
                .then((results) {
                  final ids = results.map((r) => r['f_TimelineEvent_brick_id']);
                  return Future.wait<TimelineEvent>(
                    ids.map(
                      (primaryKey) => repository!
                          .getAssociation<TimelineEvent>(
                            Query.where('primaryKey', primaryKey, limit1: true),
                          )
                          .then((r) => r!.first),
                    ),
                  );
                }))
            .toList()
            .cast<TimelineEvent>(),
    markerImageUrl: data['marker_image_url'] == null
        ? null
        : data['marker_image_url'] as String?,
    displayImageUrl: data['display_image_url'] == null
        ? null
        : data['display_image_url'] as String?,
    galleryImages: data['gallery_images'] == null
        ? null
        : jsonDecode(data['gallery_images']).toList().cast<String>(),
    audioUrl: data['audio_url'] == null ? null : data['audio_url'] as String?,
    videoUrls: data['video_urls'] == null
        ? null
        : jsonDecode(data['video_urls']).toList().cast<String>(),
    model3dUrl: data['model3d_url'] == null
        ? null
        : data['model3d_url'] as String?,
    modelThumbnailUrl: data['model_thumbnail_url'] == null
        ? null
        : data['model_thumbnail_url'] as String?,
    roomId: data['room_id'] == null ? null : data['room_id'] as String?,
    location: data['location'] == null ? null : data['location'] as String?,
    qrCode: data['qr_code'] == null ? null : data['qr_code'] as String?,
    isFeatured: data['is_featured'] == 1,
    aiContext: data['ai_context'] == null
        ? null
        : data['ai_context'] as String?,
    updatedAt: DateTime.parse(data['updated_at'] as String),
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$ArtifactToSqlite(
  Artifact instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'name': instance.name,
    'subtitle': instance.subtitle,
    'category': instance.category,
    'period': instance.period,
    'description': instance.description,
    'cultural_significance': instance.culturalSignificance,
    'additional_notes': instance.additionalNotes,
    'marker_image_url': instance.markerImageUrl,
    'display_image_url': instance.displayImageUrl,
    'gallery_images': instance.galleryImages == null
        ? null
        : jsonEncode(instance.galleryImages),
    'audio_url': instance.audioUrl,
    'video_urls': instance.videoUrls == null
        ? null
        : jsonEncode(instance.videoUrls),
    'model3d_url': instance.model3dUrl,
    'model_thumbnail_url': instance.modelThumbnailUrl,
    'room_id': instance.roomId,
    'location': instance.location,
    'qr_code': instance.qrCode,
    'is_featured': instance.isFeatured ? 1 : 0,
    'ai_context': instance.aiContext,
    'updated_at': instance.updatedAt.toIso8601String(),
  };
}

/// Construct a [Artifact]
class ArtifactAdapter extends OfflineFirstWithSupabaseAdapter<Artifact> {
  ArtifactAdapter();

  @override
  final supabaseTableName = 'artifacts';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'name': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'name',
    ),
    'subtitle': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'subtitle',
    ),
    'category': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'category',
    ),
    'period': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'period',
    ),
    'description': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'description',
    ),
    'culturalSignificance': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'cultural_significance',
    ),
    'additionalNotes': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'additional_notes',
    ),
    'timeline': const RuntimeSupabaseColumnDefinition(
      association: true,
      columnName: 'timeline',
      associationType: TimelineEvent,
      associationIsNullable: true,
    ),
    'markerImageUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'marker_image_url',
    ),
    'displayImageUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'display_image_url',
    ),
    'galleryImages': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'gallery_images',
    ),
    'audioUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'audio_url',
    ),
    'videoUrls': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'video_urls',
    ),
    'model3dUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'model_3d_url',
    ),
    'modelThumbnailUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'model_thumbnail_url',
    ),
    'roomId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'room_id',
    ),
    'location': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'location',
    ),
    'qrCode': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'qr_code',
    ),
    'isFeatured': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'is_featured',
    ),
    'aiContext': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'ai_context',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
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
    'name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'name',
      iterable: false,
      type: String,
    ),
    'subtitle': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'subtitle',
      iterable: false,
      type: String,
    ),
    'category': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'category',
      iterable: false,
      type: String,
    ),
    'period': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'period',
      iterable: false,
      type: String,
    ),
    'description': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'description',
      iterable: false,
      type: String,
    ),
    'culturalSignificance': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'cultural_significance',
      iterable: false,
      type: String,
    ),
    'additionalNotes': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'additional_notes',
      iterable: false,
      type: String,
    ),
    'timeline': const RuntimeSqliteColumnDefinition(
      association: true,
      columnName: 'timeline',
      iterable: true,
      type: TimelineEvent,
    ),
    'markerImageUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'marker_image_url',
      iterable: false,
      type: String,
    ),
    'displayImageUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'display_image_url',
      iterable: false,
      type: String,
    ),
    'galleryImages': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'gallery_images',
      iterable: true,
      type: String,
    ),
    'audioUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'audio_url',
      iterable: false,
      type: String,
    ),
    'videoUrls': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'video_urls',
      iterable: true,
      type: String,
    ),
    'model3dUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'model3d_url',
      iterable: false,
      type: String,
    ),
    'modelThumbnailUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'model_thumbnail_url',
      iterable: false,
      type: String,
    ),
    'roomId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'room_id',
      iterable: false,
      type: String,
    ),
    'location': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'location',
      iterable: false,
      type: String,
    ),
    'qrCode': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'qr_code',
      iterable: false,
      type: String,
    ),
    'isFeatured': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'is_featured',
      iterable: false,
      type: bool,
    ),
    'aiContext': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'ai_context',
      iterable: false,
      type: String,
    ),
    'updatedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'updated_at',
      iterable: false,
      type: DateTime,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    Artifact instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `Artifact` WHERE id = ? OR qr_code = ? LIMIT 1''',
      [instance.id, instance.qrCode],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'Artifact';
  @override
  Future<void> afterSave(instance, {required provider, repository}) async {
    if (instance.primaryKey != null) {
      final timelineOldColumns = await provider.rawQuery(
        'SELECT `f_TimelineEvent_brick_id` FROM `_brick_Artifact_timeline` WHERE `l_Artifact_brick_id` = ?',
        [instance.primaryKey],
      );
      final timelineOldIds = timelineOldColumns.map(
        (a) => a['f_TimelineEvent_brick_id'],
      );
      final timelineNewIds =
          instance.timeline?.map((s) => s.primaryKey).whereType<int>() ?? [];
      final timelineIdsToDelete = timelineOldIds.where(
        (id) => !timelineNewIds.contains(id),
      );

      await Future.wait<void>(
        timelineIdsToDelete.map((id) async {
          return await provider
              .rawExecute(
                'DELETE FROM `_brick_Artifact_timeline` WHERE `l_Artifact_brick_id` = ? AND `f_TimelineEvent_brick_id` = ?',
                [instance.primaryKey, id],
              )
              .catchError((e) => null);
        }),
      );

      await Future.wait<int?>(
        instance.timeline?.map((s) async {
              final id =
                  s.primaryKey ??
                  await provider.upsert<TimelineEvent>(
                    s,
                    repository: repository,
                  );
              return await provider.rawInsert(
                'INSERT OR IGNORE INTO `_brick_Artifact_timeline` (`l_Artifact_brick_id`, `f_TimelineEvent_brick_id`) VALUES (?, ?)',
                [instance.primaryKey, id],
              );
            }) ??
            [],
      );
    }
  }

  @override
  Future<Artifact> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ArtifactFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    Artifact input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ArtifactToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Artifact> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ArtifactFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    Artifact input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ArtifactToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
