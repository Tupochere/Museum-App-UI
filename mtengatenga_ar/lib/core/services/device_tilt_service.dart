import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceTiltReading {
  const DeviceTiltReading({
    required this.x,
    required this.y,
    required this.z,
    required this.isFlat,
  });

  final double x;
  final double y;
  final double z;
  final bool isFlat;

  factory DeviceTiltReading.fromEvent(dynamic event) {
    final data = Map<Object?, Object?>.from(event as Map);
    return DeviceTiltReading(
      x: (data['x'] as num?)?.toDouble() ?? 0,
      y: (data['y'] as num?)?.toDouble() ?? 0,
      z: (data['z'] as num?)?.toDouble() ?? 0,
      isFlat: data['isFlat'] == true,
    );
  }
}

class DeviceTiltService {
  DeviceTiltService();

  static const EventChannel _channel = EventChannel(
    'mtengatenga_ar/device_tilt',
  );

  Stream<DeviceTiltReading> get readings {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<DeviceTiltReading>.empty();
    }

    return _channel.receiveBroadcastStream().map(DeviceTiltReading.fromEvent);
  }
}
