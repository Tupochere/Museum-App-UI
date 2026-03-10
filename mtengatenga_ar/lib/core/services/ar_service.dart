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
