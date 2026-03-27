import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/foundation.dart';

/// Readiness state for plane detection confidence.
enum PlaneReadiness {
  /// No valid planes detected yet.
  scanning,

  /// At least one valid plane detected, building confidence.
  candidate,

  /// Enough stable detections — surface is ready for placement.
  ready,
}

/// Encapsulates plane quality assessment, confidence tracking, timeout
/// management, and instant-placement decisions for the AR viewer.
///
/// Instantiated per AR session (not a singleton). The widget delegates
/// detection logic here instead of holding state inline.
class PlaneDetectionService {
  // ---------------------------------------------------------------------------
  // Constants (relaxed from legacy ar_artifact_viewer thresholds)
  // ---------------------------------------------------------------------------

  /// Minimum width or depth a plane must span to count.
  static const double minPlaneExtentMeters = 0.15; // legacy: 0.22

  /// Minimum surface area (extendX × extendZ) to count.
  static const double minPlaneAreaMeters2 = 0.03; // legacy: 0.06

  /// How many valid plane callbacks before we reach [PlaneReadiness.ready].
  static const int requiredStableDetections = 3; // legacy: 8

  /// If no valid plane arrives within this window, decay confidence.
  static const Duration planeStaleTimeout = Duration(seconds: 3); // legacy: 2s

  /// Closest a hit-test can be to the camera and still be accepted.
  static const double minPlacementDistance = 0.15; // legacy: 0.20

  /// Farthest a hit-test can be from the camera and still be accepted.
  static const double maxPlacementDistance = 4.00; // legacy: 3.00

  /// After this much time in [PlaneReadiness.scanning] with zero planes,
  /// offer instant (non-anchored) placement as a fallback.
  static const Duration instantPlacementTimeout = Duration(seconds: 10);

  /// Default distance in front of the camera for instant placement.
  static const double instantPlacementDistance = 1.5;

  // ---------------------------------------------------------------------------
  // Observable state
  // ---------------------------------------------------------------------------

  PlaneReadiness _readiness = PlaneReadiness.scanning;
  int _stableDetections = 0;
  double _bestPlaneArea = 0.0;
  DateTime _lastPlaneDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _trackingState = 'PAUSED';
  bool _instantPlacementAvailable = false;
  DateTime _sessionStartedAt = DateTime.now();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  PlaneReadiness get readiness => _readiness;
  int get stableDetections => _stableDetections;
  double get bestPlaneArea => _bestPlaneArea;
  String get trackingState => _trackingState;
  bool get isTracking => _trackingState == 'TRACKING';
  bool get instantPlacementAvailable => _instantPlacementAvailable;

  /// Progress ratio from 0.0 (no detections) to 1.0 (ready).
  double get confidenceRatio =>
      (_stableDetections / requiredStableDetections).clamp(0.0, 1.0);

  /// Whether enough time has elapsed with no planes to offer instant placement.
  bool get shouldOfferInstantPlacement =>
      _instantPlacementAvailable &&
      _readiness == PlaneReadiness.scanning;

  /// Contextual guidance message for the user based on current state.
  String get guidanceMessage {
    if (!isTracking) {
      return 'Move slowly and point at a textured surface';
    }
    if (_instantPlacementAvailable && _readiness == PlaneReadiness.scanning) {
      return 'Having trouble detecting a surface? Place model freely.';
    }
    switch (_readiness) {
      case PlaneReadiness.scanning:
        return 'Scanning for a surface...';
      case PlaneReadiness.candidate:
        final pct = (confidenceRatio * 100).toInt();
        return 'Surface detected! Stabilizing... $pct%';
      case PlaneReadiness.ready:
        return 'Surface ready! Tap to place';
    }
  }

  /// Secondary guidance line shown below the main status.
  String get surfaceHintMessage {
    if (_readiness == PlaneReadiness.ready) {
      return 'Surface ready. Tap where you want to place the model.';
    }
    return 'Point at a flat, textured area. White dots indicate tracking.';
  }

  // ---------------------------------------------------------------------------
  // Phase 1: Hit filtering
  // ---------------------------------------------------------------------------

  /// Returns only the hits whose distance falls within the accepted range,
  /// sorted nearest-first. Accepts all plane types (horizontal + vertical).
  List<ArCoreHitTestResult> filterHits(List<ArCoreHitTestResult> hits) {
    final valid = hits.where((h) {
      final d = h.distance;
      return d >= minPlacementDistance && d <= maxPlacementDistance;
    }).toList();
    valid.sort((a, b) => a.distance.compareTo(b.distance));
    return valid;
  }

  // ---------------------------------------------------------------------------
  // Phase 2: Real-time plane evaluation
  // ---------------------------------------------------------------------------

  /// Evaluates an incoming [ArCorePlane] from the `onPlaneDetected` callback.
  ///
  /// Returns `true` if the plane passed validation and was counted.
  bool evaluatePlane(ArCorePlane plane) {
    // Accept horizontal (up/down) and vertical planes.
    final type = plane.type;
    if (type != ArCorePlaneType.HORIZONTAL_UPWARD_FACING &&
        type != ArCorePlaneType.HORIZONTAL_DOWNWARD_FACING &&
        type != ArCorePlaneType.VERTICAL) {
      return false;
    }

    final extendX = (plane.extendX ?? 0).abs();
    final extendZ = (plane.extendZ ?? 0).abs();
    final area = extendX * extendZ;

    if (extendX < minPlaneExtentMeters ||
        extendZ < minPlaneExtentMeters ||
        area < minPlaneAreaMeters2) {
      return false;
    }

    // Plane is valid — update confidence.
    _lastPlaneDetectedAt = DateTime.now();
    if (area > _bestPlaneArea) _bestPlaneArea = area;

    if (_stableDetections < requiredStableDetections) {
      _stableDetections++;
    }
    _updateReadiness();
    return true;
  }

  /// Update tracking state from the ARCore session poll.
  void onTrackingStateUpdate(String state) {
    _trackingState = state;
    if (!isTracking && _stableDetections > 0) {
      // Decay confidence while tracking is degraded.
      _stableDetections = (_stableDetections - 1).clamp(0, requiredStableDetections);
      _updateReadiness();
    }
  }

  /// Periodic tick — call every ~500 ms. Handles stale-plane decay and
  /// instant-placement timeout.
  void tick() {
    _decayIfStale();
    _checkInstantPlacementTimeout();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets all detection state. Call when the AR session starts or when the
  /// user resets model placement.
  void reset() {
    _stableDetections = 0;
    _bestPlaneArea = 0.0;
    _lastPlaneDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);
    _trackingState = 'PAUSED';
    _instantPlacementAvailable = false;
    _sessionStartedAt = DateTime.now();
    _updateReadiness();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _updateReadiness() {
    if (_stableDetections >= requiredStableDetections) {
      _readiness = PlaneReadiness.ready;
    } else if (_stableDetections > 0) {
      _readiness = PlaneReadiness.candidate;
    } else {
      _readiness = PlaneReadiness.scanning;
    }
  }

  void _decayIfStale() {
    if (_stableDetections <= 0) return;
    if (_readiness == PlaneReadiness.ready) return; // don't decay once ready

    final elapsed = DateTime.now().difference(_lastPlaneDetectedAt);
    if (elapsed > planeStaleTimeout) {
      _stableDetections = (_stableDetections - 1).clamp(0, requiredStableDetections);
      debugPrint('PlaneDetectionService: stale decay → $_stableDetections');
      _updateReadiness();
    }
  }

  void _checkInstantPlacementTimeout() {
    if (_instantPlacementAvailable) return;
    if (_readiness != PlaneReadiness.scanning) return;

    final elapsed = DateTime.now().difference(_sessionStartedAt);
    if (elapsed > instantPlacementTimeout) {
      _instantPlacementAvailable = true;
      debugPrint('PlaneDetectionService: instant placement now available');
    }
  }
}
