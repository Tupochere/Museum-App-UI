import 'package:flutter/material.dart';

import '../models/artifact.dart';
import '../services/supabase_service.dart';
import '../theme/app_tokens.dart';
import '../utils/ar_detector.dart';
import 'ar_artifact_viewer.dart';
import 'model_3d_viewer.dart';

enum _ViewerMode { ar, preview3d }

class ArtifactViewerScreen extends StatefulWidget {
  const ArtifactViewerScreen({super.key, required this.artifactId});

  final String artifactId;

  @override
  State<ArtifactViewerScreen> createState() => _ArtifactViewerScreenState();
}

class _ArtifactViewerScreenState extends State<ArtifactViewerScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  ArSupportStatus _arStatus = ArSupportStatus.checking;
  Artifact? _artifact;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtifactAndMode();
  }

  Future<void> _loadArtifactAndMode() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _arStatus = ArSupportStatus.checking;
    });

    try {
      final results = await Future.wait<Object?>([
        ArDetector.checkAvailability(),
        _supabaseService.getArtifact(widget.artifactId),
      ]);

      if (!mounted) return;

      final arStatus = results[0]! as ArSupportStatus;
      final artifact = results[1] as Artifact?;

      final viewerMode = _selectViewerMode(arStatus, artifact);
      final modeLabel = viewerMode == _ViewerMode.ar ? 'AR Mode' : '3D Preview';
      debugPrint('Device mode resolved for "${widget.artifactId}": $modeLabel');

      setState(() {
        _arStatus = arStatus;
        _artifact = artifact;
        _isLoading = false;
        _errorMessage = artifact == null
            ? 'No artifact found for QR code: ${widget.artifactId}'
            : null;
      });
    } catch (error, stackTrace) {
      debugPrint('Artifact viewer initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load artifact. Check your connection.';
      });
    }
  }

  _ViewerMode _selectViewerMode(ArSupportStatus arStatus, Artifact? artifact) {
    final modelUrl = artifact?.model3dUrl?.trim();
    final hasModelUrl = modelUrl != null && modelUrl.isNotEmpty;
    if (arStatus == ArSupportStatus.arSupported && hasModelUrl) {
      return _ViewerMode.ar;
    }
    return _ViewerMode.preview3d;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _arStatus == ArSupportStatus.checking) {
      return _buildLoadingState();
    }

    if (_errorMessage != null || _artifact == null) {
      return _buildErrorState();
    }

    final viewerMode = _selectViewerMode(_arStatus, _artifact);
    if (viewerMode == _ViewerMode.ar) {
      return ArArtifactViewer(artifact: _artifact!);
    }

    return Model3DViewer(artifact: _artifact!);
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 14),
                Text(
                  'Checking device mode and loading artifact...',
                  textAlign: TextAlign.center,
                  style: AppText.cardSubtitle.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: AppColors.surfaceCard,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.arrow_back, color: AppColors.textMain),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to open artifact',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Something went wrong.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadArtifactAndMode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
