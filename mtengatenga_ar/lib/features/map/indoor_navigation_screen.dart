import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/models/indoor_navigation.dart';
import '../../core/services/indoor_navigation_service.dart';
import '../../theme/app_tokens.dart';
import '../ar/ar_navigation_screen.dart';

class IndoorNavigationScreen extends StatefulWidget {
  const IndoorNavigationScreen({
    super.key,
    IndoorNavigationService? navigationService,
  }) : _navigationService = navigationService;

  final IndoorNavigationService? _navigationService;

  @override
  State<IndoorNavigationScreen> createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen> {
  static const String _fullTourValue = 'full_tour';

  late final IndoorNavigationService _navigationService =
      widget._navigationService ??
      GetIt.instance.get<IndoorNavigationService>();

  String _selectedDestination = _fullTourValue;

  @override
  void initState() {
    super.initState();
    _navigationService.reset();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _navigationService.mode;
    final currentTarget = _navigationService.currentTarget;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        actions: [
          IconButton(
            tooltip: 'Switch to AR',
            onPressed: _openArNavigation,
            icon: const Icon(Icons.view_in_ar),
          ),
          IconButton(
            tooltip: 'Reset route',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: MeasuredRoomMap(
                  service: _navigationService,
                  activeTargetId: currentTarget?.id,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (mode) {
                IndoorNavigationMode.setup => _SetupSheet(
                  key: const ValueKey('setup'),
                  service: _navigationService,
                  selectedDestination: _selectedDestination,
                  onDestinationChanged: (value) {
                    setState(() => _selectedDestination = value);
                  },
                  onPreview: _previewRoute,
                ),
                IndoorNavigationMode.preview => _PreviewSheet(
                  key: const ValueKey('preview'),
                  service: _navigationService,
                  onStart: _startNavigation,
                  onReset: _reset,
                ),
                IndoorNavigationMode.active => _ActiveSheet(
                  key: const ValueKey('active'),
                  service: _navigationService,
                  onArrived: _markArrived,
                  onReset: _reset,
                ),
                IndoorNavigationMode.complete => _CompleteSheet(
                  key: const ValueKey('complete'),
                  service: _navigationService,
                  onReset: _reset,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _previewRoute() {
    setState(() {
      if (_selectedDestination == _fullTourValue) {
        _navigationService.previewFullTour();
      } else {
        _navigationService.previewDestination(_selectedDestination);
      }
    });
  }

  void _startNavigation() {
    setState(_navigationService.startNavigation);
  }

  void _markArrived() {
    setState(_navigationService.markArrived);
  }

  void _reset() {
    setState(() {
      _selectedDestination = _fullTourValue;
      _navigationService.reset();
    });
  }

  Future<void> _openArNavigation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArNavigationScreen()),
    );
    if (!mounted) return;
    setState(() {
      _selectedDestination = _fullTourValue;
      _navigationService.reset();
    });
  }
}

class MeasuredRoomMap extends StatelessWidget {
  const MeasuredRoomMap({
    super.key,
    required this.service,
    this.activeTargetId,
  });

  final IndoorNavigationService service;
  final String? activeTargetId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CustomPaint(
          painter: _MeasuredRoomPainter(
            service: service,
            activeTargetId: activeTargetId,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SetupSheet extends StatelessWidget {
  const _SetupSheet({
    super.key,
    required this.service,
    required this.selectedDestination,
    required this.onDestinationChanged,
    required this.onPreview,
  });

  final IndoorNavigationService service;
  final String selectedDestination;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            title: 'Measured Room Map',
            subtitle: 'Door to window route with 4 artifact stops.',
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: selectedDestination,
            decoration: const InputDecoration(
              labelText: 'Destination',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: _IndoorNavigationScreenState._fullTourValue,
                child: Text('Full tour'),
              ),
              ...service.artifacts.map(
                (artifact) => DropdownMenuItem(
                  value: artifact.id,
                  child: Text(artifact.name),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) onDestinationChanged(value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.route),
              label: const Text('Preview Route'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    super.key,
    required this.service,
    required this.onStart,
    required this.onReset,
  });

  final IndoorNavigationService service;
  final VoidCallback onStart;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final routeLabel = service.isFullTour
        ? 'Full tour'
        : service.activeRoute.first.name;

    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: routeLabel,
            subtitle:
                '${service.activeRoute.length} stop route - ${_meters(service.totalDistanceMeters)} total',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final step in service.routeSteps)
                Chip(
                  label: Text(
                    '${step.to.name}: ${_meters(step.distanceMeters)}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.tune),
                  label: const Text('Change'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Start Navigation'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveSheet extends StatelessWidget {
  const _ActiveSheet({
    super.key,
    required this.service,
    required this.onArrived,
    required this.onReset,
  });

  final IndoorNavigationService service;
  final VoidCallback onArrived;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final target = service.currentTarget;
    final progress =
        '${service.activeIndex + 1} of ${service.activeRoute.length}';

    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: target?.name ?? 'Route complete',
            subtitle:
                '$progress - ${_meters(service.currentLegDistanceMeters)} from current stop',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.close),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onArrived,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I'm here"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompleteSheet extends StatelessWidget {
  const _CompleteSheet({
    super.key,
    required this.service,
    required this.onReset,
  });

  final IndoorNavigationService service;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: 'Tour complete',
            subtitle:
                '${service.visitedCount} artifacts visited - ${_meters(service.totalDistanceMeters)} walked',
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.replay),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.tileTitle.copyWith(color: AppColors.textMain),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppText.tileSubtitle.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MeasuredRoomPainter extends CustomPainter {
  _MeasuredRoomPainter({required this.service, required this.activeTargetId});

  final IndoorNavigationService service;
  final String? activeTargetId;

  static const double _labelSpace = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final mapRect = _mapRect(size);
    final roomPaint = Paint()
      ..color = const Color(0xFFFFFBF4)
      ..style = PaintingStyle.fill;
    final wallPaint = Paint()
      ..color = AppColors.textMain
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final narrowPaint = Paint()
      ..color = AppColors.surfaceBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRect(mapRect, roomPaint);
    canvas.drawRect(mapRect, wallPaint);
    _drawNarrowedRear(canvas, mapRect, narrowPaint);
    _drawGrid(canvas, mapRect);
    _drawTable(canvas, mapRect);
    _drawRoute(canvas, mapRect);
    _drawArtifacts(canvas, mapRect);
    _drawLabels(canvas, mapRect);
  }

  Rect _mapRect(Size size) {
    final available = Size(
      math.max(1, size.width - (_labelSpace * 2)),
      math.max(1, size.height - (_labelSpace * 2)),
    );
    final scale = math.min(
      available.width / IndoorNavigationService.roomWidthMeters,
      available.height / IndoorNavigationService.roomLengthMeters,
    );
    final width = IndoorNavigationService.roomWidthMeters * scale;
    final height = IndoorNavigationService.roomLengthMeters * scale;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }

  Offset _toCanvas(IndoorPoint point, Rect rect) {
    final xRatio = point.xMeters / IndoorNavigationService.roomWidthMeters;
    final yRatio = point.yMeters / IndoorNavigationService.roomLengthMeters;
    return Offset(
      rect.left + (xRatio * rect.width),
      rect.bottom - (yRatio * rect.height),
    );
  }

  Rect _toCanvasRect(IndoorObstacle obstacle, Rect rect) {
    final topLeft = _toCanvas(
      IndoorPoint(
        xMeters: obstacle.origin.xMeters,
        yMeters: obstacle.origin.yMeters + obstacle.lengthMeters,
      ),
      rect,
    );
    final bottomRight = _toCanvas(
      IndoorPoint(
        xMeters: obstacle.origin.xMeters + obstacle.widthMeters,
        yMeters: obstacle.origin.yMeters,
      ),
      rect,
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = AppColors.surfaceBorder.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    for (
      var meter = 1;
      meter < IndoorNavigationService.roomWidthMeters;
      meter++
    ) {
      final x =
          rect.left +
          (meter / IndoorNavigationService.roomWidthMeters) * rect.width;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
    for (
      var meter = 1;
      meter < IndoorNavigationService.roomLengthMeters;
      meter++
    ) {
      final y =
          rect.bottom -
          (meter / IndoorNavigationService.roomLengthMeters) * rect.height;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
  }

  void _drawNarrowedRear(Canvas canvas, Rect rect, Paint paint) {
    const rearStartY = 7.2;
    const narrowWidth = IndoorNavigationService.narrowedRearWidthMeters;
    const sideInset =
        (IndoorNavigationService.roomWidthMeters - narrowWidth) / 2;
    final leftStart = _toCanvas(
      const IndoorPoint(xMeters: sideInset, yMeters: rearStartY),
      rect,
    );
    final leftEnd = _toCanvas(
      const IndoorPoint(
        xMeters: sideInset,
        yMeters: IndoorNavigationService.roomLengthMeters,
      ),
      rect,
    );
    final rightStart = _toCanvas(
      const IndoorPoint(
        xMeters: IndoorNavigationService.roomWidthMeters - sideInset,
        yMeters: rearStartY,
      ),
      rect,
    );
    final rightEnd = _toCanvas(
      const IndoorPoint(
        xMeters: IndoorNavigationService.roomWidthMeters - sideInset,
        yMeters: IndoorNavigationService.roomLengthMeters,
      ),
      rect,
    );

    canvas.drawLine(leftStart, leftEnd, paint);
    canvas.drawLine(rightStart, rightEnd, paint);
  }

  void _drawTable(Canvas canvas, Rect rect) {
    final tableRect = _toCanvasRect(service.table, rect);
    final fill = Paint()
      ..color = const Color(0xFFE8D7C5)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      border,
    );
    _drawText(
      canvas,
      service.table.label,
      tableRect.center,
      color: AppColors.textMain,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      centered: true,
    );
  }

  void _drawRoute(Canvas canvas, Rect rect) {
    if (!service.hasRoute) return;

    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routeStart = _toCanvas(service.routeStartPoint, rect);
    final path = Path()
      ..moveTo(
        routeStart.dx,
        routeStart.dy,
      );

    for (final waypoint in service.activeRoute) {
      final point = _toCanvas(waypoint.point, rect);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, routePaint);
    canvas.drawCircle(routeStart, 5, Paint()..color = AppColors.primaryDark);
  }

  void _drawArtifacts(Canvas canvas, Rect rect) {
    for (final artifact in service.artifacts) {
      final point = _toCanvas(artifact.point, rect);
      final active = artifact.id == activeTargetId;
      final markerPaint = Paint()
        ..color = active ? AppColors.primary : const Color(0xFF2F6F73)
        ..style = PaintingStyle.fill;
      final ringPaint = Paint()
        ..color = active ? AppColors.primaryDark : Colors.white
        ..strokeWidth = active ? 4 : 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(point, active ? 11 : 8, markerPaint);
      canvas.drawCircle(point, active ? 13 : 10, ringPaint);
      _drawText(
        canvas,
        artifact.name.replaceFirst('Artifact ', 'A'),
        point.translate(0, -22),
        color: AppColors.textMain,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        centered: true,
      );
    }
  }

  void _drawLabels(Canvas canvas, Rect rect) {
    _drawText(
      canvas,
      'WINDOW / BACK',
      Offset(rect.center.dx, rect.top - 14),
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      centered: true,
    );
    _drawText(
      canvas,
      'DOOR / ENTRANCE',
      Offset(rect.center.dx, rect.bottom + 16),
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      centered: true,
    );
    _drawText(
      canvas,
      'LEFT',
      Offset(rect.left - 18, rect.center.dy),
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      centered: true,
    );
    _drawText(
      canvas,
      'RIGHT',
      Offset(rect.right + 20, rect.center.dy),
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      centered: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = centered
        ? offset - Offset(painter.width / 2, painter.height / 2)
        : offset;
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _MeasuredRoomPainter oldDelegate) {
    return true;
  }
}

String _meters(double value) => '${value.toStringAsFixed(1)} m';
