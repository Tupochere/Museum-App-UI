/// Pure business entity representing an artifact from the museum database.
/// This maps directly to the Supabase 'artifacts' table.
class Artifact {
  final String id;
  final String name;
  final String description;
  final String? roomId;
  final String? markerImageUrl;
  final String? audioUrl;
  final String? model3dUrl;
  final DateTime updatedAt;

  const Artifact({
    required this.id,
    required this.name,
    required this.description,
    this.roomId,
    this.markerImageUrl,
    this.audioUrl,
    this.model3dUrl,
    required this.updatedAt,
  });

  /// Factory for creating from Supabase JSON
  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      roomId: json['room_id'] as String?,
      markerImageUrl: json['marker_image_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      model3dUrl: json['model3d_url'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to UiArtifactSummary for display
  /// (You'll use this later to bridge domain -> UI)
}
