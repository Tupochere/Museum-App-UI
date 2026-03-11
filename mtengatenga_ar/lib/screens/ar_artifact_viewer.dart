import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../core/services/model_manager_service.dart';
import '../models/artifact.dart';
import '../theme/app_tokens.dart';
import 'model_3d_viewer.dart';

class ArArtifactViewer extends StatefulWidget {
  const ArArtifactViewer({super.key, required this.artifact});

  final Artifact artifact;

  @override
  State<ArArtifactViewer> createState() => _ArArtifactViewerState();
}

class _ArArtifactViewerState extends State<ArArtifactViewer> {
  static const String _nodeName = 'artifact_ar_node';

  final ModelManagerService _modelManagerService = ModelManagerService();

  ArCoreController? _controller;
  ArCoreReferenceNode? _placedNode;

  String? _preparedModelUri;
  String? _errorMessage;
  bool _isPreparingModel = true;
  bool _isPlacingModel = false;
  bool _isModelPlaced = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Device mode: AR Mode');
    _prepareModel();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepareModel() async {
    final modelSource = widget.artifact.model3dUrl?.trim();
    if (modelSource == null || modelSource.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isPreparingModel = false;
        _errorMessage = 'This artifact does not have a 3D model URL yet.';
      });
      return;
    }

    if (!_modelManagerService.isSupportedSource(modelSource)) {
      if (!mounted) return;
      setState(() {
        _isPreparingModel = false;
        _errorMessage = 'Unsupported model format. Expected .glb or .gltf.';
      });
      return;
    }

    try {
      final result = await _modelManagerService.resolveModel(
        artifactId: widget.artifact.id,
        source: modelSource,
      );

      if (!mounted) return;
      setState(() {
        _preparedModelUri = result.localFileUri;
        _isPreparingModel = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AR model preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isPreparingModel = false;
        _errorMessage = 'Failed to load 3D model for AR.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreparingModel) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null || _preparedModelUri == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enablePlaneRenderer: true,
              enableTapRecognizer: true,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const _ModeBanner(
                        label: 'AR Mode',
                        color: Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FDFBF7),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      widget.artifact.name,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FDFBF7),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Text(
                      _isModelPlaced
                          ? 'Model placed. Tap another plane area to reposition.'
                          : 'Move your phone slowly and tap a detected flat surface to place the artifact.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isPlacingModel)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  _CircleBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const _ModeBanner(label: 'AR Mode', color: Color(0xFF2E7D32)),
                ],
              ),
              const Spacer(),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                'Preparing AR model...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleBackButton(onPressed: () => Navigator.of(context).pop()),
              const SizedBox(height: 18),
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
                      'AR unavailable for this artifact',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage ?? 'AR failed to start.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _open3DPreview,
                      icon: const Icon(Icons.threed_rotation),
                      label: const Text('Open 3D Preview'),
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

  void _onArCoreViewCreated(ArCoreController controller) {
    _controller = controller;
    controller.onPlaneTap = _onPlaneTap;
    controller.onError = _onArError;
  }

  Future<void> _onPlaneTap(List<ArCoreHitTestResult> hits) async {
    if (_isPlacingModel) return;
    if (hits.isEmpty) {
      _showMessage('No plane detected yet. Move phone and try again.');
      return;
    }

    final controller = _controller;
    final modelUri = _preparedModelUri;
    if (controller == null || modelUri == null) return;

    if (!mounted) return;
    setState(() => _isPlacingModel = true);

    try {
      if (_placedNode?.name != null) {
        await controller.removeNode(nodeName: _placedNode!.name);
      }
    } catch (_) {
      // Removal failures should not block new placement.
    }

    try {
      final hit = hits.first;
      final node = ArCoreReferenceNode(
        name: _nodeName,
        objectUrl: modelUri,
        position: hit.pose.translation.clone(),
        rotation: hit.pose.rotation.clone(),
        scale: vector.Vector3.all(0.35),
      );

      _placedNode = node;
      await controller.addArCoreNodeWithAnchor(node);

      if (!mounted) return;
      setState(() => _isModelPlaced = true);
      _showMessage('Model placed successfully.');
    } catch (error, stackTrace) {
      debugPrint('AR placement failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not place model on that surface.');
    } finally {
      if (mounted) {
        setState(() => _isPlacingModel = false);
      }
    }
  }

  void _onArError(String message) {
    debugPrint('ArCoreView error: $message');
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  void _open3DPreview() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Model3DViewer(artifact: widget.artifact),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9FDFBF7),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
