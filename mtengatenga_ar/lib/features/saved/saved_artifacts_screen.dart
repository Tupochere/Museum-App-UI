import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/domain/entities/artifact.model.dart';
import '../../core/domain/repositories/artifact_repository.dart';
import '../../core/services/saved_artifacts_service.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';

class SavedArtifactsScreen extends StatefulWidget {
  const SavedArtifactsScreen({super.key});

  @override
  State<SavedArtifactsScreen> createState() => _SavedArtifactsScreenState();
}

class _SavedArtifactsScreenState extends State<SavedArtifactsScreen> {
  final _savedService = GetIt.instance<SavedArtifactsService>();
  final _artifactRepo = GetIt.instance<IArtifactRepository>();

  List<Artifact> _artifacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _savedService.addListener(_onSavedChanged);
    _loadArtifacts();
  }

  @override
  void dispose() {
    _savedService.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() => _loadArtifacts();

  Future<void> _loadArtifacts() async {
    final ids = _savedService.value.toList();
    if (ids.isEmpty) {
      if (mounted) setState(() { _artifacts = []; _loading = false; });
      return;
    }

    try {
      final all = await _artifactRepo.getAllArtifacts();
      final saved = all.where((a) => ids.contains(a.id)).toList();
      if (mounted) setState(() { _artifacts = saved; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Saved Artifacts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _artifacts.isEmpty
              ? const AppEmptyState(
                  title: 'No Saved Artifacts',
                  message:
                      'Tap the heart icon on any artifact to save it here for quick access.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _artifacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final artifact = _artifacts[index];
                    return _SavedArtifactTile(
                      artifact: artifact,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ArtifactDetailsScreen(artifact: artifact),
                          ),
                        );
                      },
                      onUnsave: () => _savedService.toggle(artifact.id),
                    );
                  },
                ),
    );
  }
}

class _SavedArtifactTile extends StatelessWidget {
  const _SavedArtifactTile({
    required this.artifact,
    required this.onTap,
    required this.onUnsave,
  });

  final Artifact artifact;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final hasImage = artifact.displayImageUrl != null &&
        artifact.displayImageUrl!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(artifact.displayImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasImage
                  ? null
                  : const Icon(Icons.museum_outlined,
                      color: AppColors.primary),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (artifact.subtitle != null) artifact.subtitle!,
                      if (artifact.period != null) artifact.period!,
                    ].join(' \u2022 '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unsave button
            IconButton(
              icon: const Icon(Icons.favorite, color: Color(0xFFE07A5F)),
              onPressed: onUnsave,
              tooltip: 'Remove from saved',
            ),
          ],
        ),
      ),
    );
  }
}
