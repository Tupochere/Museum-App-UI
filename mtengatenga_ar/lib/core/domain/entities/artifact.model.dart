import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'artifacts'),
)
class Artifact extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String name;

  final String? subtitle;

  final String? category;

  final String? period;

  @Supabase(name: 'description')
  @Sqlite(name: 'description')
  final String description;

  @Supabase(name: 'cultural_significance')
  @Sqlite(name: 'cultural_significance')
  final String? culturalSignificance;

  @Supabase(name: 'additional_notes')
  @Sqlite(name: 'additional_notes')
  final String? additionalNotes;

  final List<TimelineEvent>? timeline;

  @Supabase(name: 'marker_image_url')
  @Sqlite(name: 'marker_image_url')
  final String? markerImageUrl;

  @Supabase(name: 'display_image_url')
  @Sqlite(name: 'display_image_url')
  final String? displayImageUrl;

  @Supabase(name: 'gallery_images')
  @Sqlite(name: 'gallery_images')
  final List<String>? galleryImages;

  @Supabase(name: 'audio_url')
  @Sqlite(name: 'audio_url')
  final String? audioUrl;

  @Supabase(name: 'video_urls')
  @Sqlite(name: 'video_urls')
  final List<String>? videoUrls;

  @Supabase(name: 'model_3d_url')
  @Sqlite(name: 'model3d_url')
  final String? model3dUrl;

  @Supabase(name: 'model_thumbnail_url')
  @Sqlite(name: 'model_thumbnail_url')
  final String? modelThumbnailUrl;

  @Supabase(name: 'room_id')
  @Sqlite(name: 'room_id')
  final String? roomId;

  final String? location;

  @Supabase(name: 'qr_code')
  @Sqlite(name: 'qr_code', unique: true)
  final String? qrCode;

  @Supabase(name: 'is_featured')
  @Sqlite(name: 'is_featured')
  final bool isFeatured;

  @Supabase(name: 'ai_context')
  @Sqlite(name: 'ai_context')
  final String? aiContext;

  @Supabase(name: 'updated_at')
  @Sqlite(name: 'updated_at')
  final DateTime updatedAt;

  Artifact({
    required this.id,
    required this.name,
    this.subtitle,
    this.category,
    this.period,
    required this.description,
    this.culturalSignificance,
    this.additionalNotes,
    this.timeline,
    this.markerImageUrl,
    this.displayImageUrl,
    this.galleryImages,
    this.audioUrl,
    this.videoUrls,
    this.model3dUrl,
    this.modelThumbnailUrl,
    this.roomId,
    this.location,
    this.qrCode,
    this.isFeatured = false,
    this.aiContext,
    required this.updatedAt,
  });
}

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'timeline_events'),
)
class TimelineEvent extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String? id;

  final String year;

  final String event;

  @Supabase(name: 'artifact_id')
  @Sqlite(name: 'artifact_id')
  final String? artifactId;

  TimelineEvent({
    this.id,
    required this.year,
    required this.event,
    this.artifactId,
  });
}
