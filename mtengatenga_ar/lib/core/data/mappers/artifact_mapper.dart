import '../../domain/entities/artifact.dart';
import '../../models/ui_models.dart';

/// Maps domain Artifact entities to UI presentation models
class ArtifactMapper {
  /// Convert Artifact to UiArtifactSummary for display in lists/cards
  static UiArtifactSummary toUiSummary(Artifact artifact, {bool saved = false}) {
    return UiArtifactSummary(
      id: artifact.id,
      name: artifact.name,
      subtitle: artifact.subtitle ?? _extractSubtitle(artifact.description),
      period: artifact.period ?? _formatPeriod(artifact.updatedAt),
      imageUrl: artifact.displayImageUrl ?? artifact.markerImageUrl ?? '',
      saved: saved,
    );
  }

  /// Convert a list of Artifacts to UiArtifactSummary list
  static List<UiArtifactSummary> toUiSummaryList(
    List<Artifact> artifacts, {
    Set<String> savedIds = const {},
  }) {
    return artifacts.map((artifact) {
      return toUiSummary(artifact, saved: savedIds.contains(artifact.id));
    }).toList();
  }

  /// Extract first ~60 chars of description as subtitle
  static String _extractSubtitle(String description) {
    if (description.length <= 60) return description;
    return '${description.substring(0, 57)}...';
  }

  /// Format date as a period/year string for display
  static String _formatPeriod(DateTime date) {
    return date.year.toString();
  }
}
