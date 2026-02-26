class Artifact {
  final String id;
  final String name;
  final String? subtitle;
  final String? category;
  final String? period;

  // Content
  final String description;
  final String? culturalSignificance;
  final String? additionalNotes;

  // Timeline (History tab)
  final List<TimelineEvent>? timeline;

  // Media
  final String? markerImageUrl;
  final String? displayImageUrl;
  final List<String>? galleryImages;
  final String? audioUrl;
  final List<String>? videoUrls;
  final String? model3dUrl;
  final String? modelThumbnailUrl;

  // Metadata
  final String? roomId;
  final String? location;
  final String? qrCode;
  final bool isFeatured;

  final DateTime updatedAt;

  const Artifact({
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
    required this.updatedAt,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String?,
      category: json['category'] as String?,
      period: json['period'] as String?,
      description: json['description'] as String,
      culturalSignificance: json['cultural_significance'] as String?,
      additionalNotes: json['additional_notes'] as String?,
      timeline: json['timeline'] != null
          ? (json['timeline'] as List)
              .map(
                (e) => TimelineEvent.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : null,
      markerImageUrl: json['marker_image_url'] as String?,
      displayImageUrl: json['display_image_url'] as String?,
      galleryImages: json['gallery_images'] != null
          ? List<String>.from(json['gallery_images'] as List)
          : null,
      audioUrl: json['audio_url'] as String?,
      videoUrls: json['video_urls'] != null
          ? List<String>.from(json['video_urls'] as List)
          : null,
      model3dUrl: json['model3d_url'] as String?,
      modelThumbnailUrl: json['model_thumbnail_url'] as String?,
      roomId: json['room_id'] as String?,
      location: json['location'] as String?,
      qrCode: json['qr_code'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TimelineEvent {
  final String year;
  final String event;

  const TimelineEvent({required this.year, required this.event});

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      year: json['year'] as String,
      event: json['event'] as String,
    );
  }
}
