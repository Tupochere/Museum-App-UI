import 'dart:async';

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../core/domain/entities/artifact.model.dart';
import '../../core/services/ar_service.dart';
import '../../core/services/model_manager_service.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';

enum ArViewerState {
  initializing,
  detectingSurfaces,
  modelLoading,
  modelPlaced,
  arNotSupported,
  noModel,
  error,
}

class ArViewerScreen extends StatefulWidget {
  const ArViewerScreen({super.key, required this.artifact});

  final Artifact artifact;

  @override
  State<ArViewerScreen> createState() => _ArViewerScreenState();
}

class _ArViewerScreenState extends State<ArViewerScreen>
    with WidgetsBindingObserver {
  static const String _modelNodeName = 'artifact_model_node';
  static const double _minScale = 0.10;
  static const double _maxScale = 3.00;
  static const double _dragSensitivity = 0.0015;
  static const Map<String, String> _testModelAssetByQrCode = {
    'MASK001': 'assets/models/mask_placeholder.glb',
    'SHIELD001': 'assets/models/shield_placeholder.glb',
  };
  static const String _defaultPlaceholderModel =
      'assets/models/cube_placeholder.glb';

  final ArService _arService = ArService();
  final ModelManagerService _modelManagerService = ModelManagerService();

  ArCoreController? _arController;
  ArCoreReferenceNode? _currentNode;
  Timer? _nodeRefreshTimer;

  ArViewerState _viewerState = ArViewerState.initializing;
  String? _errorMessage;
  String? _modelUrl;

  bool _hasHorizontalSurface = false;
  bool _isRefreshingNode = false;
  bool _canRenderArView = false;
  bool _usedCachedModel = false;
  String? _activeModelSource;
  double? _downloadProgress;
  DateTime _lastNoSurfaceHintAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isControlsCollapsed = false;

  vector.Vector3? _placementPosition;
  vector.Vector4? _placementRotation;

  double _modelScale = 0.35;
  double _modelRotationY = 0.0;
  double _gestureStartScale = 0.35;
  double _gestureStartRotation = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareArSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _arService.handleLifecycleState(state);
  }

  @override
  void dispose() {
    _nodeRefreshTimer?.cancel();
    _arService.disposeSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _prepareArSession() async {
    final primarySource = widget.artifact.model3dUrl?.trim();
    final fallbackSource = _placeholderModelForArtifact(widget.artifact.qrCode);

    final availability = await _arService.checkAvailability();
    if (!mounted) return;

    switch (availability) {
      case ArAvailabilityStatus.supported:
        break;
      case ArAvailabilityStatus.unsupported:
      case ArAvailabilityStatus.needsInstall:
      case ArAvailabilityStatus.unknown:
      case ArAvailabilityStatus.error:
        setState(() => _viewerState = ArViewerState.arNotSupported);
        return;
    }

    setState(() {
      _viewerState = ArViewerState.modelLoading;
      _downloadProgress = null;
    });

    final sourceCandidate = (primarySource != null && primarySource.isNotEmpty)
        ? primarySource
        : fallbackSource;

    if (!_modelManagerService.isSupportedSource(sourceCandidate)) {
      _setError('Unsupported model format. Use .glb or .gltf files.');
      return;
    }

    try {
      final model = await _modelManagerService.resolveModel(
        artifactId: widget.artifact.id,
        source: sourceCandidate,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress = progress.ratio);
        },
      );

      if (!mounted) return;

      setState(() {
        _modelUrl = model.localFileUri;
        _activeModelSource = model.source;
        _usedCachedModel = model.usedCache;
        _downloadProgress = null;
        _viewerState = ArViewerState.initializing;
        _canRenderArView = true;
      });
    } catch (error) {
      // If remote model fails, retry once with placeholder asset.
      if (primarySource != null && primarySource.isNotEmpty) {
        try {
          final fallbackModel = await _modelManagerService.resolveModel(
            artifactId: widget.artifact.id,
            source: fallbackSource,
          );
          if (!mounted) return;
          setState(() {
            _modelUrl = fallbackModel.localFileUri;
            _activeModelSource = fallbackModel.source;
            _usedCachedModel = fallbackModel.usedCache;
            _downloadProgress = null;
            _viewerState = ArViewerState.initializing;
            _canRenderArView = true;
          });
          return;
        } catch (_) {
          // Continue to surface the original model error.
        }
      }

      final message = error is ModelManagerException
          ? error.message
          : 'Failed to prepare 3D model for AR.';
      _setError(message);
    }
  }

  String _placeholderModelForArtifact(String? qrCode) {
    final normalized = qrCode?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return _defaultPlaceholderModel;
    }
    return _testModelAssetByQrCode[normalized] ?? _defaultPlaceholderModel;
  }

  String _loadingProgressText() {
    final ratio = _downloadProgress;
    if (ratio == null) return 'Loading 3D model...';
    final percentage = (ratio * 100).clamp(0, 100).toStringAsFixed(0);
    return 'Loading 3D model... $percentage%';
  }

  String _modelSourceText() {
    if (_activeModelSource == null) return 'Model source pending...';
    return _usedCachedModel
        ? 'Model loaded from local cache.'
        : 'Model loaded from network/assets.';
  }

  @override
  Widget build(BuildContext context) {
    if (_viewerState == ArViewerState.noModel) {
      return _buildFallbackScaffold(
        title: '3D model not available',
        message:
            'This artifact does not have a 3D model URL yet. You can continue to full details.',
      );
    }

    if (_viewerState == ArViewerState.arNotSupported) {
      return _buildFallbackScaffold(
        title: 'AR not available on this device',
        message:
            'ARCore support was not detected. You can continue to the artifact detail screen.',
      );
    }

    if (_viewerState == ArViewerState.error) {
      return _buildFallbackScaffold(
        title: 'AR session error',
        message: _errorMessage ?? 'AR session initialization failed.',
      );
    }

    if (!_canRenderArView) {
      return _buildPendingScaffold();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enableTapRecognizer: true,
              enablePlaneRenderer: true,
              enableUpdateListener: false,
              debug: false,
            ),
          ),
          if (_viewerState == ArViewerState.modelPlaced)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _RoundTextButton(
                        label: 'View Details',
                        onPressed: _openArtifactDetails,
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildControlsOverlay(),
                ],
              ),
            ),
          ),
          if (_viewerState == ArViewerState.initializing ||
              _viewerState == ArViewerState.modelLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedCrossFade(
      firstChild: _buildExpandedControlsOverlay(),
      secondChild: _buildCollapsedControlsOverlay(),
      crossFadeState: _isControlsCollapsed
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 220),
      firstCurve: Curves.easeOutCubic,
      secondCurve: Curves.easeInCubic,
      sizeCurve: Curves.easeInOutCubic,
      alignment: Alignment.bottomCenter,
    );
  }

  Widget _buildExpandedControlsOverlay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _setControlsCollapsed(true),
                tooltip: 'Minimize controls',
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _surfaceStatusText,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _modelSourceText(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_viewerState == ArViewerState.modelPlaced) ...[
            const SizedBox(height: 12),
            const Text(
              'Pinch to resize and twist to rotate. Use +/- for fine control.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.remove,
                  onPressed: () => _adjustScale(-0.05),
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.add,
                  onPressed: () => _adjustScale(0.05),
                ),
                const SizedBox(width: 12),
                Text(
                  'Scale ${(100 * _modelScale).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_viewerState == ArViewerState.modelPlaced)
                ElevatedButton.icon(
                  onPressed: _resetPlacement,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _openArtifactDetails,
                icon: const Icon(Icons.info_outline),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedControlsOverlay() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _setControlsCollapsed(false),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: const Color(0xD9FDFBF7),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Controls minimized. Tap to expand.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
    );
  }

  void _setControlsCollapsed(bool collapsed) {
    if (_isControlsCollapsed == collapsed) return;
    setState(() => _isControlsCollapsed = collapsed);
  }

  Widget _buildFallbackScaffold({
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openArtifactDetails,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Scan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openArtifactDetails,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Exit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _statusText {
    switch (_viewerState) {
      case ArViewerState.initializing:
        return 'Starting AR session...';
      case ArViewerState.detectingSurfaces:
        return _hasHorizontalSurface
            ? 'Tap surface to place model'
            : 'Move camera slowly, then tap on a flat surface';
      case ArViewerState.modelLoading:
        return _loadingProgressText();
      case ArViewerState.modelPlaced:
        return 'Model placed. Drag to move, pinch to scale, twist to rotate.';
      case ArViewerState.arNotSupported:
        return 'AR not available on this device';
      case ArViewerState.noModel:
        return '3D model not available';
      case ArViewerState.error:
        return _errorMessage ?? 'AR session initialization failed.';
    }
  }

  String get _surfaceStatusText {
    if (!_hasHorizontalSurface) {
      return 'No surface confirmed yet. White dots mean tracking is working. Point at a flat, textured area and tap to test placement.';
    }
    return 'Surface detected. Tap where you want to place the model.';
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    _arController = controller;
    _arService.initializeSession(controller);
    controller.onError = _handleArError;
    controller.onPlaneTap = _handlePlaneTap;

    if (!mounted) return;
    setState(() => _viewerState = ArViewerState.detectingSurfaces);
  }

  Future<void> _handlePlaneTap(List<ArCoreHitTestResult> hits) async {
    if (_modelUrl == null) return;
    if (_viewerState == ArViewerState.modelLoading) return;
    if (hits.isEmpty) {
      _showNoSurfaceHint();
      return;
    }

    if (!_hasHorizontalSurface && mounted) {
      setState(() => _hasHorizontalSurface = true);
    }

    final hit = hits.first;
    _placementPosition = hit.pose.translation.clone();
    _placementRotation = hit.pose.rotation.clone();

    await _placeModelAtCurrentPose(showLoadingState: true);
  }

  void _showNoSurfaceHint() {
    final now = DateTime.now();
    if (now.difference(_lastNoSurfaceHintAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastNoSurfaceHintAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('No surface yet. Move slowly and tap a flat area.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _placeModelAtCurrentPose({
    required bool showLoadingState,
  }) async {
    final controller = _arController;
    final modelUrl = _modelUrl;
    final position = _placementPosition;
    final rotation = _placementRotation;
    if (controller == null ||
        modelUrl == null ||
        position == null ||
        rotation == null) {
      return;
    }

    if (showLoadingState && mounted) {
      setState(() => _viewerState = ArViewerState.modelLoading);
    }

    try {
      if (_currentNode?.name != null) {
        await controller.removeNode(nodeName: _currentNode!.name);
      }
    } catch (_) {
      // Ignore remove failures; a fresh add can still succeed.
    }

    try {
      final node = ArCoreReferenceNode(
        name: _modelNodeName,
        objectUrl: modelUrl,
        position: position,
        rotation: _composeRotation(rotation),
        scale: vector.Vector3.all(_modelScale),
      );

      _currentNode = node;
      await controller.addArCoreNodeWithAnchor(node);

      if (!mounted) return;
      setState(() {
        _viewerState = ArViewerState.modelPlaced;
        _errorMessage = null;
      });
    } catch (error) {
      _setError(_friendlyArError(error.toString()));
    }
  }

  vector.Vector4 _composeRotation(vector.Vector4 baseRotation) {
    final base = vector.Quaternion(
      baseRotation.x,
      baseRotation.y,
      baseRotation.z,
      baseRotation.w,
    );
    final yRotation = vector.Quaternion.axisAngle(
      vector.Vector3(0, 1, 0),
      _modelRotationY,
    );
    final combined = base * yRotation;
    return vector.Vector4(combined.x, combined.y, combined.z, combined.w);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _modelScale;
    _gestureStartRotation = _modelRotationY;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_viewerState != ArViewerState.modelPlaced || _currentNode == null) {
      return;
    }

    if (details.pointerCount <= 1) {
      final currentPosition = _currentNode?.position?.value;
      if (currentPosition == null) return;

      final updated = vector.Vector3(
        currentPosition.x + (details.focalPointDelta.dx * _dragSensitivity),
        currentPosition.y,
        currentPosition.z + (details.focalPointDelta.dy * _dragSensitivity),
      );

      _currentNode?.position?.value = updated;
      _placementPosition = updated;
      return;
    }

    final nextScale = (_gestureStartScale * details.scale).clamp(
      _minScale,
      _maxScale,
    );
    final nextRotation = _gestureStartRotation + details.rotation;

    final scaleChanged = (nextScale - _modelScale).abs() > 0.01;
    final rotationChanged = (nextRotation - _modelRotationY).abs() > 0.01;
    if (!scaleChanged && !rotationChanged) return;

    if (!mounted) return;
    setState(() {
      _modelScale = nextScale.toDouble();
      _modelRotationY = nextRotation;
    });

    _scheduleNodeRefresh();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scheduleNodeRefresh();
  }

  void _scheduleNodeRefresh() {
    _nodeRefreshTimer?.cancel();
    _nodeRefreshTimer = Timer(const Duration(milliseconds: 140), () async {
      await _refreshNodeTransform();
    });
  }

  Future<void> _refreshNodeTransform() async {
    if (_isRefreshingNode) return;
    _isRefreshingNode = true;
    try {
      await _placeModelAtCurrentPose(showLoadingState: false);
    } finally {
      _isRefreshingNode = false;
    }
  }

  Future<void> _adjustScale(double delta) async {
    if (_viewerState != ArViewerState.modelPlaced) return;

    final nextScale = (_modelScale + delta).clamp(_minScale, _maxScale);
    if (nextScale == _modelScale) return;

    if (!mounted) return;
    setState(() => _modelScale = nextScale.toDouble());

    await _refreshNodeTransform();
  }

  Future<void> _resetPlacement() async {
    _nodeRefreshTimer?.cancel();
    final controller = _arController;
    if (controller != null && _currentNode?.name != null) {
      try {
        await controller.removeNode(nodeName: _currentNode!.name);
      } catch (_) {
        // Reset should continue even when remove call fails.
      }
    }

    if (!mounted) return;
    setState(() {
      _currentNode = null;
      _placementPosition = null;
      _placementRotation = null;
      _hasHorizontalSurface = false;
      _modelScale = 0.35;
      _modelRotationY = 0.0;
      _viewerState = ArViewerState.detectingSurfaces;
    });
  }

  void _handleArError(String message) {
    _setError(_friendlyArError(message));
  }

  String _friendlyArError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('camera') && normalized.contains('permission')) {
      return 'Camera permission denied. Enable camera permission and try again.';
    }
    if (normalized.contains('camera')) {
      return 'Camera is not available for AR session.';
    }
    if (normalized.contains('network') ||
        normalized.contains('unable to resolve host') ||
        normalized.contains('timed out')) {
      return 'Network error while loading the 3D model.';
    }
    if (normalized.contains('renderable') ||
        normalized.contains('gltf') ||
        normalized.contains('model')) {
      return 'Unable to load the 3D model from the provided URL.';
    }
    return 'AR session initialization failed.';
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _viewerState = ArViewerState.error;
    });
  }

  Future<void> _openArtifactDetails() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactDetailsScreen(artifact: widget.artifact),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9FDFBF7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textMain),
        ),
      ),
    );
  }
}

class _RoundTextButton extends StatelessWidget {
  const _RoundTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9FDFBF7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
