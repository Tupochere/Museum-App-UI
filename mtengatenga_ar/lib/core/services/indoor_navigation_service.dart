import '../models/indoor_navigation.dart';

class IndoorNavigationService {
  IndoorNavigationService();

  static const double roomWidthMeters = 6.07;
  static const double roomLengthMeters = 10.62;
  static const double narrowedRearWidthMeters = 3.82;
  static const IndoorPoint entrancePoint = IndoorPoint(xMeters: 0, yMeters: 0);

  final IndoorObstacle table = const IndoorObstacle(
    label: 'Table',
    origin: IndoorPoint(xMeters: 2.57, yMeters: 3.64),
    widthMeters: 1.50,
    lengthMeters: 6.02,
  );

  late final List<IndoorArtifactWaypoint> artifacts = [
    IndoorArtifactWaypoint(
      id: 'artifact_1',
      name: 'Artifact 1',
      point: pointFromDoorAndRightWall(
        fromDoorMeters: 3.84,
        fromRightWallMeters: 3.31,
      ),
    ),
    IndoorArtifactWaypoint(
      id: 'artifact_2',
      name: 'Artifact 2',
      point: pointFromDoorAndRightWall(
        fromDoorMeters: 9.46,
        fromRightWallMeters: 3.31,
      ),
    ),
    IndoorArtifactWaypoint(
      id: 'artifact_3',
      name: 'Artifact 3',
      point: pointFromDoorAndRightWall(
        fromDoorMeters: 9.46,
        fromRightWallMeters: 2.20,
      ),
    ),
    IndoorArtifactWaypoint(
      id: 'artifact_4',
      name: 'Artifact 4',
      point: pointFromDoorAndRightWall(
        fromDoorMeters: 3.84,
        fromRightWallMeters: 2.20,
      ),
    ),
  ];

  List<String> get fullTourOrder => const [
    'artifact_1',
    'artifact_2',
    'artifact_3',
    'artifact_4',
  ];

  IndoorNavigationMode _mode = IndoorNavigationMode.setup;
  List<IndoorArtifactWaypoint> _activeRoute = [];
  IndoorPoint? _routeStartPoint;
  String _routeStartLabel = 'Entrance';
  int _activeIndex = 0;

  IndoorNavigationMode get mode => _mode;
  List<IndoorArtifactWaypoint> get activeRoute =>
      List.unmodifiable(_activeRoute);
  int get activeIndex => _activeIndex;
  bool get hasRoute => _activeRoute.isNotEmpty;
  bool get isFullTour => _activeRoute.length > 1;
  IndoorPoint get routeStartPoint => _routeStartPoint ?? entrancePoint;
  String get routeStartLabel => _routeStartLabel;

  IndoorArtifactWaypoint? get currentTarget {
    if (_activeRoute.isEmpty || _activeIndex >= _activeRoute.length) {
      return null;
    }
    return _activeRoute[_activeIndex];
  }

  IndoorPoint get currentStartPoint {
    if (_activeIndex <= 0) return routeStartPoint;
    return _activeRoute[_activeIndex - 1].point;
  }

  String get currentStartLabel {
    if (_activeIndex <= 0) return routeStartLabel;
    return _activeRoute[_activeIndex - 1].name;
  }

  List<IndoorRouteStep> get routeSteps {
    final steps = <IndoorRouteStep>[];
    var fromPoint = routeStartPoint;
    var fromLabel = routeStartLabel;

    for (final waypoint in _activeRoute) {
      steps.add(
        IndoorRouteStep(
          fromLabel: fromLabel,
          to: waypoint,
          from: fromPoint,
          distanceMeters: fromPoint.distanceTo(waypoint.point),
        ),
      );
      fromPoint = waypoint.point;
      fromLabel = waypoint.name;
    }

    return steps;
  }

  double get totalDistanceMeters =>
      routeSteps.fold<double>(0, (total, step) => total + step.distanceMeters);

  double get currentLegDistanceMeters {
    final target = currentTarget;
    if (target == null) return 0;
    return currentStartPoint.distanceTo(target.point);
  }

  int get visitedCount {
    if (_mode == IndoorNavigationMode.complete) return _activeRoute.length;
    return _activeIndex.clamp(0, _activeRoute.length);
  }

  IndoorPoint pointFromDoorAndRightWall({
    required double fromDoorMeters,
    required double fromRightWallMeters,
  }) {
    return IndoorPoint(
      xMeters: roomWidthMeters - fromRightWallMeters,
      yMeters: fromDoorMeters,
    );
  }

  IndoorArtifactWaypoint artifactById(String id) {
    return artifacts.firstWhere((artifact) => artifact.id == id);
  }

  void previewFullTour() {
    _routeStartPoint = null;
    _routeStartLabel = 'Entrance';
    _activeRoute = fullTourOrder.map(artifactById).toList();
    _activeIndex = 0;
    _mode = IndoorNavigationMode.preview;
  }

  void previewDestination(String artifactId) {
    _routeStartPoint = null;
    _routeStartLabel = 'Entrance';
    _activeRoute = [artifactById(artifactId)];
    _activeIndex = 0;
    _mode = IndoorNavigationMode.preview;
  }

  void startArNavigationFromMarker(int markerNumber) {
    final markerId = 'artifact_$markerNumber';
    final marker = artifactById(markerId);
    final remaining = fullTourOrder
        .skip(markerNumber)
        .map(artifactById)
        .toList();

    _routeStartPoint = marker.point;
    _routeStartLabel = 'Marker $markerNumber';
    _activeRoute = remaining;
    _activeIndex = 0;
    _mode = remaining.isEmpty
        ? IndoorNavigationMode.complete
        : IndoorNavigationMode.active;
  }

  void startTourAfterArtifact(String artifactId) {
    final currentArtifact = artifactById(artifactId);
    final startIndex = fullTourOrder.indexOf(artifactId);
    final remainingIds = startIndex < 0
        ? fullTourOrder
        : fullTourOrder.skip(startIndex + 1);

    _routeStartPoint = currentArtifact.point;
    _routeStartLabel = currentArtifact.name;
    _activeRoute = remainingIds.map(artifactById).toList();
    _activeIndex = 0;
    _mode = _activeRoute.isEmpty
        ? IndoorNavigationMode.complete
        : IndoorNavigationMode.active;
  }

  void startNavigation() {
    if (_activeRoute.isEmpty) previewFullTour();
    _activeIndex = 0;
    _mode = IndoorNavigationMode.active;
  }

  void markArrived() {
    if (_mode != IndoorNavigationMode.active || _activeRoute.isEmpty) return;

    if (_activeIndex >= _activeRoute.length - 1) {
      _activeIndex = _activeRoute.length;
      _mode = IndoorNavigationMode.complete;
      return;
    }

    _activeIndex += 1;
  }

  void reset() {
    _mode = IndoorNavigationMode.setup;
    _activeRoute = [];
    _routeStartPoint = null;
    _routeStartLabel = 'Entrance';
    _activeIndex = 0;
  }
}
