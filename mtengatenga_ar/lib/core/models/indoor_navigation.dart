import 'dart:math' as math;

class IndoorPoint {
  const IndoorPoint({required this.xMeters, required this.yMeters});

  final double xMeters;
  final double yMeters;

  double distanceTo(IndoorPoint other) {
    final dx = xMeters - other.xMeters;
    final dy = yMeters - other.yMeters;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}

class IndoorArtifactWaypoint {
  const IndoorArtifactWaypoint({
    required this.id,
    required this.name,
    required this.point,
  });

  final String id;
  final String name;
  final IndoorPoint point;
}

class IndoorObstacle {
  const IndoorObstacle({
    required this.label,
    required this.origin,
    required this.widthMeters,
    required this.lengthMeters,
  });

  final String label;
  final IndoorPoint origin;
  final double widthMeters;
  final double lengthMeters;

  IndoorPoint get center => IndoorPoint(
    xMeters: origin.xMeters + (widthMeters / 2),
    yMeters: origin.yMeters + (lengthMeters / 2),
  );
}

class IndoorRouteStep {
  const IndoorRouteStep({
    required this.fromLabel,
    required this.to,
    required this.from,
    required this.distanceMeters,
  });

  final String fromLabel;
  final IndoorArtifactWaypoint to;
  final IndoorPoint from;
  final double distanceMeters;
}

enum IndoorNavigationMode { setup, preview, active, complete }
