import 'dart:async';
import 'dart:math' as math;

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../core/services/model_manager_service.dart';
import '../models/artifact.dart';
import '../theme/app_tokens.dart';
import 'model_3d_viewer.dart';

enum PlaneReadiness { scanning, candidate, locked }

class ArArtifactViewer extends StatefulWidget {
  const ArArtifactViewer({super.key, required this.artifact});

  final Artifact artifact;

  @override
  State<ArArtifactViewer> createState() => _ArArtifactViewerState();
}

class _ArArtifactViewerState extends State<ArArtifactViewer> {
  static const String _nodeName = 'artifact_ar_node';
  static const double _minPlaneExtentMeters = 0.12;
  static const double _minPlaneAreaMeters2 = 0.015;
  static const int _requiredStableDetections = 3;
  static const Duration _planeStaleTimeout = Duration(seconds: 3);
  static const Duration _trackingPollInterval = Duration(milliseconds: 450);
  static const Duration _lockFallbackDelay = Duration(seconds: 8);
  static const double _minPlacementDistanceMeters = 0.10;
  static const double _maxPlacementDistanceMeters = 3.00;
  static const String _trackingStateTracking = 'TRACKING';
  static const String _trackingStatePaused = 'PAUSED';

  final ModelManagerService _modelManagerService = ModelManagerService();

  ArCoreController? _controller;
  ArCoreReferenceNode? _placedNode;
  Timer? _trackingPollTimer;
  Timer? _lockFallbackTimer;
  bool _lockedByFallback = false;

  String? _preparedModelUri;
  String? _errorMessage;
  bool _isPreparingModel = true;
  bool _isPlacingModel = false;
  bool _isModelPlaced = false;
  bool _isTrackingPollInFlight = false;

  PlaneReadiness _planeReadiness = PlaneReadiness.scanning;
  int _stablePlaneDetections = 0;
  double _bestPlaneArea = 0.0;
  DateTime _lastPlaneDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _trackingState = _trackingStatePaused;
  bool _hasShownLockedMessage = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Device mode: AR Mode');
    _prepareModel();
  }

  @override
  void dispose() {
    _stopTrackingPolling();
    _lockFallbackTimer?.cancel();
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
              enableUpdateListener: true,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isModelPlaced
                              ? 'Model placed. Use "Place anywhere" to reset.'
                              : _scanStatusText,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _isPlacingModel ? null : _placeAnywhere,
                          icon: const Icon(Icons.center_focus_strong),
                          label: Text(
                            _isModelPlaced ? 'Place again in front' : 'Place anywhere',
                          ),
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
    controller.onPlaneDetected = _onPlaneDetected;
    controller.onError = _onArError;
    _resetSurfaceDetectionState(clearBestPlaneArea: true);
    _startTrackingPolling();
    _startLockFallbackTimer();
  }

  void _startLockFallbackTimer() {
    _lockFallbackTimer?.cancel();
    _lockFallbackTimer = Timer(_lockFallbackDelay, () {
      if (!mounted || _isModelPlaced) return;
      if (_planeReadiness == PlaneReadiness.locked) return;
      debugPrint('Lock fallback: forcing PlaneReadiness.locked after timeout.');
      setState(() {
        _planeReadiness = PlaneReadiness.locked;
        _lockedByFallback = true;
      });
      _showMessage('Detection slow - tap any visible surface to place.');
    });
  }

  Future<void> _onPlaneTap(List<ArCoreHitTestResult> hits) async {
    if (_isPlacingModel) return;
    if (_planeReadiness != PlaneReadiness.locked) {
      debugPrint('Placement blocked: surface is not locked yet.');
      _showMessage('Keep scanning until surface locks.');
      return;
    }
    if (hits.isEmpty) {
      _showMessage('No plane detected at tap. Try a textured area.');
      return;
    }

    final validHits = hits
        .where(
          (hit) =>
              hit.distance >= _minPlacementDistanceMeters &&
              hit.distance <= _maxPlacementDistanceMeters,
        )
        .toList(growable: false);

    if (validHits.isEmpty) {
      debugPrint('Placement blocked: no hits within allowed distance range.');
      _showMessage(
        'Move slightly closer or farther, then tap again on the same surface.',
      );
      return;
    }

    validHits.sort((a, b) => a.distance.compareTo(b.distance));

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
      final hit = validHits.first;
      final node = ArCoreReferenceNode(
        name: _nodeName,
        objectUrl: modelUri,
        position: hit.pose.translation.clone(),
        rotation: hit.pose.rotation.clone(),
        scale: vector.Vector3.all(1.5),
      );

      _placedNode = node;
      await controller.addArCoreNodeWithAnchor(node);

      if (!mounted) return;
      setState(() {
        _isModelPlaced = true;
        _planeReadiness = PlaneReadiness.locked;
      });
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

  Future<void> _placeAnywhere() async {
    if (_isPlacingModel) return;
    final controller = _controller;
    final modelUri = _preparedModelUri;
    if (controller == null || modelUri == null) {
      _showMessage('AR session not ready yet.');
      return;
    }

    _lockFallbackTimer?.cancel();

    if (!mounted) return;
    setState(() => _isPlacingModel = true);

    try {
      if (_placedNode?.name != null) {
        await controller.removeNode(nodeName: _placedNode!.name);
      }
    } catch (_) {}

    try {
      final node = ArCoreReferenceNode(
        name: _nodeName,
        objectUrl: modelUri,
        position: vector.Vector3(0, -0.3, -0.8),
        rotation: vector.Vector4(0, 0, 0, 1),
        scale: vector.Vector3.all(1.5),
      );

      _placedNode = node;
      await controller.addArCoreNode(node);

      if (!mounted) return;
      setState(() {
        _isModelPlaced = true;
        _planeReadiness = PlaneReadiness.locked;
      });
      _showMessage('Model placed in front of you.');
    } catch (error, stackTrace) {
      debugPrint('Place anywhere failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not place model.');
    } finally {
      if (mounted) {
        setState(() => _isPlacingModel = false);
      }
    }
  }

  void _onArError(String message) {
    debugPrint('ArCoreView error: $message');
    _stopTrackingPolling();
    _lockFallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _planeReadiness = PlaneReadiness.scanning;
      _stablePlaneDetections = 0;
      _hasShownLockedMessage = false;
      _lockedByFallback = false;
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

  void _startTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = Timer.periodic(_trackingPollInterval, (_) async {
      if (_isTrackingPollInFlight || !mounted) return;
      _isTrackingPollInFlight = true;
      try {
        final controller = _controller;
        if (controller == null) return;

        final rawResult = await controller.getTrackingState();
        final nextTracking = _extractTrackingState(rawResult, controller);

        if (nextTracking != _trackingState && mounted) {
          debugPrint(
            'Tracking state changed: $_trackingState -> $nextTracking',
          );
          setState(() => _trackingState = nextTracking);
        }

        _resetIfSurfaceIsStale();
      } catch (_) {
        if (mounted && _trackingState != _trackingStatePaused) {
          debugPrint(
            'Tracking polling fallback: $_trackingState -> $_trackingStatePaused',
          );
          setState(() => _trackingState = _trackingStatePaused);
        }
      } finally {
        _isTrackingPollInFlight = false;
      }
    });
  }

  void _stopTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = null;
  }

  String _extractTrackingState(dynamic rawResult, ArCoreController controller) {
    final direct = rawResult?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final fallback = controller.trackingState.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return _trackingStatePaused;
  }

  void _onPlaneDetected(ArCorePlane plane) {
    if (!mounted || _isModelPlaced) return;
    if (plane.type != ArCorePlaneType.HORIZONTAL_UPWARD_FACING) {
      return;
    }

    final extendX = (plane.extendX ?? 0).abs();
    final extendZ = (plane.extendZ ?? 0).abs();
    final area = extendX * extendZ;

    if (extendX < _minPlaneExtentMeters ||
        extendZ < _minPlaneExtentMeters ||
        area < _minPlaneAreaMeters2) {
      return;
    }

    _lastPlaneDetectedAt = DateTime.now();
    _bestPlaneArea = math.max(_bestPlaneArea, area);

    if (_stablePlaneDetections < _requiredStableDetections) {
      _stablePlaneDetections++;
    }

    _updatePlaneReadiness(showLockMessage: true);
  }

  void _resetIfSurfaceIsStale() {
    if (_stablePlaneDetections == 0 || _isModelPlaced) return;
    final elapsed = DateTime.now().difference(_lastPlaneDetectedAt);
    if (elapsed <= _planeStaleTimeout) return;

    debugPrint('Surface confidence reset: stale plane detections.');
    _resetSurfaceDetectionState(clearBestPlaneArea: false);
  }

  void _decreaseDetectionConfidence() {
    if (_stablePlaneDetections <= 0 || _isModelPlaced) return;

    _stablePlaneDetections = math.max(0, _stablePlaneDetections - 1);
    _updatePlaneReadiness(showLockMessage: false);
  }

  void _resetSurfaceDetectionState({required bool clearBestPlaneArea}) {
    _stablePlaneDetections = 0;
    _hasShownLockedMessage = false;
    _lastPlaneDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (clearBestPlaneArea) {
      _bestPlaneArea = 0.0;
    }
    _updatePlaneReadiness(showLockMessage: false);
  }

  void _updatePlaneReadiness({required bool showLockMessage}) {
    final nextReadiness = _readinessFromDetections(_stablePlaneDetections);
    if (!mounted) return;

    if (nextReadiness != _planeReadiness) {
      debugPrint('Plane readiness changed: $_planeReadiness -> $nextReadiness');
      setState(() => _planeReadiness = nextReadiness);
    } else {
      setState(() {});
    }

    if (nextReadiness == PlaneReadiness.locked &&
        showLockMessage &&
        !_hasShownLockedMessage) {
      _hasShownLockedMessage = true;
      _showMessage('Surface locked. Tap to place.');
    }
  }

  PlaneReadiness _readinessFromDetections(int detections) {
    if (detections >= _requiredStableDetections) {
      return PlaneReadiness.locked;
    }
    if (detections <= 0) {
      return PlaneReadiness.scanning;
    }
    return PlaneReadiness.candidate;
  }

  double get _confidenceRatio {
    final ratio = _stablePlaneDetections / _requiredStableDetections;
    return ratio.clamp(0.0, 1.0);
  }

  String get _scanStatusText {
    switch (_planeReadiness) {
      case PlaneReadiness.scanning:
        return 'Scanning for a flat surface...';
      case PlaneReadiness.candidate:
        final pct = (_confidenceRatio * 100).toStringAsFixed(0);
        return 'Stabilizing surface... $pct%';
      case PlaneReadiness.locked:
        if (_lockedByFallback) {
          return 'Detection slow - tap any visible surface to place.';
        }
        return 'Surface locked. Tap to place model.';
    }
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
