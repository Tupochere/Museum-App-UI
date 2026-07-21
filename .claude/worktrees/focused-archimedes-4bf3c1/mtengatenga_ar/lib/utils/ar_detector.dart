import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/foundation.dart';

enum ArSupportStatus { checking, arSupported, arUnsupported }

class ArDetector {
  const ArDetector._();

  static Future<ArSupportStatus> checkAvailability() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return ArSupportStatus.arUnsupported;
    }

    try {
      final isSupported = await ArCoreController.checkArCoreAvailability();
      return isSupported == true
          ? ArSupportStatus.arSupported
          : ArSupportStatus.arUnsupported;
    } catch (error, stackTrace) {
      debugPrint('AR availability check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ArSupportStatus.arUnsupported;
    }
  }
}
