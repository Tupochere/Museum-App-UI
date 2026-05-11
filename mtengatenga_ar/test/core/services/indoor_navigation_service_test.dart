import 'package:flutter_test/flutter_test.dart';
import 'package:mtengatenga_ar/core/services/indoor_navigation_service.dart';

void main() {
  group('IndoorNavigationService', () {
    test('converts right-wall measurements to app coordinates', () {
      final service = IndoorNavigationService();

      final point = service.pointFromDoorAndRightWall(
        fromDoorMeters: 3.84,
        fromRightWallMeters: 3.31,
      );

      expect(point.xMeters, closeTo(2.76, 0.001));
      expect(point.yMeters, closeTo(3.84, 0.001));
    });

    test('contains demo table-corner artifact coordinates', () {
      final service = IndoorNavigationService();

      expect(
        service.artifactById('artifact_1').point.xMeters,
        closeTo(2.76, 0.001),
      );
      expect(
        service.artifactById('artifact_1').point.yMeters,
        closeTo(3.84, 0.001),
      );
      expect(
        service.artifactById('artifact_2').point.xMeters,
        closeTo(2.76, 0.001),
      );
      expect(
        service.artifactById('artifact_2').point.yMeters,
        closeTo(9.46, 0.001),
      );
      expect(
        service.artifactById('artifact_3').point.xMeters,
        closeTo(3.87, 0.001),
      );
      expect(
        service.artifactById('artifact_3').point.yMeters,
        closeTo(9.46, 0.001),
      );
      expect(
        service.artifactById('artifact_4').point.xMeters,
        closeTo(3.87, 0.001),
      );
      expect(
        service.artifactById('artifact_4').point.yMeters,
        closeTo(3.84, 0.001),
      );
    });

    test('contains measured table bounds', () {
      final service = IndoorNavigationService();

      expect(service.table.origin.xMeters, closeTo(2.57, 0.001));
      expect(service.table.origin.yMeters, closeTo(3.64, 0.001));
      expect(service.table.widthMeters, closeTo(1.50, 0.001));
      expect(service.table.lengthMeters, closeTo(6.02, 0.001));
      expect(
        service.table.origin.yMeters + service.table.lengthMeters,
        closeTo(9.66, 0.001),
      );
    });

    test('builds full tour route and distance totals', () {
      final service = IndoorNavigationService()..previewFullTour();

      expect(service.activeRoute.map((artifact) => artifact.id), [
        'artifact_1',
        'artifact_2',
        'artifact_3',
        'artifact_4',
      ]);
      expect(service.routeSteps, hasLength(4));
      expect(service.totalDistanceMeters, closeTo(17.08, 0.01));
    });

    test('progresses through Artifact 1, 2, 3, and 4', () {
      final service = IndoorNavigationService()
        ..previewFullTour()
        ..startNavigation();

      expect(service.currentTarget?.id, 'artifact_1');
      service.markArrived();
      expect(service.currentTarget?.id, 'artifact_2');
      service.markArrived();
      expect(service.currentTarget?.id, 'artifact_3');
      service.markArrived();
      expect(service.currentTarget?.id, 'artifact_4');
      service.markArrived();
      expect(service.mode.name, 'complete');
      expect(service.currentTarget, isNull);
    });

    test('starts navigation from scanned artifact to the next stop', () {
      final service = IndoorNavigationService()
        ..startTourAfterArtifact('artifact_1');

      expect(service.routeStartLabel, 'Artifact 1');
      expect(service.currentStartLabel, 'Artifact 1');
      expect(service.currentTarget?.id, 'artifact_2');
      expect(service.currentLegDistanceMeters, closeTo(5.62, 0.01));

      service.markArrived();

      expect(service.currentStartLabel, 'Artifact 2');
      expect(service.currentTarget?.id, 'artifact_3');
      expect(service.currentLegDistanceMeters, closeTo(1.11, 0.01));
    });

    test('startArNavigationFromMarker(1) routes from marker through A2-A4', () {
      final service = IndoorNavigationService()
        ..startArNavigationFromMarker(1);

      expect(service.mode.name, 'active');
      expect(service.routeStartLabel, 'Marker 1');
      expect(
        service.routeStartPoint.xMeters,
        closeTo(service.artifactById('artifact_1').point.xMeters, 0.001),
      );
      expect(
        service.routeStartPoint.yMeters,
        closeTo(service.artifactById('artifact_1').point.yMeters, 0.001),
      );
      expect(service.activeRoute.map((a) => a.id), [
        'artifact_2',
        'artifact_3',
        'artifact_4',
      ]);
      expect(service.currentTarget?.id, 'artifact_2');
    });

    test('startArNavigationFromMarker(4) completes immediately', () {
      final service = IndoorNavigationService()
        ..startArNavigationFromMarker(4);

      expect(service.mode.name, 'complete');
      expect(service.activeRoute, isEmpty);
      expect(service.currentTarget, isNull);
      expect(service.routeStartLabel, 'Marker 4');
    });
  });
}
