import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum ArAvailabilityStatus {
  unknown,
  supported,
  unsupported,
  needsInstall,
  error,
}

class ArService {
  ArCoreController? _controller;
  ArAvailabilityStatus _status = ArAvailabilityStatus.unknown;
  bool _isSessionActive = false;

  ArAvailabilityStatus get status => _status;
  bool get isArAvailable => _status == ArAvailabilityStatus.supported;
  bool get isSessionActive => _isSessionActive;

  Future<ArAvailabilityStatus> checkAvailability() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _status = ArAvailabilityStatus.unsupported;
      return _status;
    }

    try {
      final availability = await ArCoreController.checkArCoreAvailability();
      if (availability != true) {
        _status = ArAvailabilityStatus.unsupported;
        return _status;
      }
      // Avoid calling checkIsArCoreInstalled() from the legacy plugin path.
      // On newer Android versions this can trigger install-activity failures.
      _status = ArAvailabilityStatus.supported;
      return _status;
    } catch (_) {
      _status = ArAvailabilityStatus.error;
      return _status;
    }
  }

  void initializeSession(ArCoreController controller) {
    _controller = controller;
    _isSessionActive = true;
  }

  /// Polls the current ARCore tracking state with defensive parsing.
  ///
  /// Returns `'TRACKING'`, `'PAUSED'`, or `'STOPPED'`.
  Future<String> pollTrackingState() async {
    final controller = _controller;
    if (controller == null || !_isSessionActive) return 'PAUSED';
    try {
      final result = await controller.getTrackingState();
      final state = result?.toString().trim();
      if (state != null && state.isNotEmpty) return state;
      // Fallback to the synchronous property.
      final fallback = controller.trackingState.trim();
      return fallback.isNotEmpty ? fallback : 'PAUSED';
    } catch (_) {
      return 'PAUSED';
    }
  }

  void resumeSession() {
    _controller?.resume();
    _isSessionActive = _controller != null;
  }

  void pauseSession() {
    _isSessionActive = false;
  }

  void handleLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        resumeSession();
        break;
      case AppLifecycleState.detached:
        disposeSession();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        pauseSession();
        break;
    }
  }

  void disposeSession() {
    _controller?.dispose();
    _controller = null;
    _isSessionActive = false;
  }
}
