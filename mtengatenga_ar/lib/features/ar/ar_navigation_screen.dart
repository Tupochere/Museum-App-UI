import 'dart:async';
import 'dart:math' as math;

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/indoor_navigation.dart';
import '../../core/services/device_tilt_service.dart';
import '../../core/services/indoor_navigation_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/ar_detector.dart';
import '../map/indoor_navigation_screen.dart';

enum _Phase { scanMarker, guiding, complete }

final RegExp _navMarkerPattern = RegExp(r'^NAV:([1-4])$');

class ArNavigationScreen extends StatefulWidget {
  const ArNavigationScreen({super.key});

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen> {
  final IndoorNavigationService _navigationService =
      GetIt.instance.get<IndoorNavigationService>();
  final DeviceTiltService _tiltService = DeviceTiltService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  StreamSubscription<DeviceTiltReading>? _tiltSubscription;
  ArCoreController? _arController;

  _Phase _phase = _Phase.scanMarker;
  ArSupportStatus _arStatus = ArSupportStatus.checking;
  bool _isFlat = true;
  bool _processingScan = false;
  int? _scannedMarker;

  @override
  void initState() {
    super.initState();
    _checkArSupport();
  }

  @override
  void dispose() {
    _tiltSubscription?.cancel();
    _arController?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _checkArSupport() async {
    final status = await ArDetector.checkAvailability();
    if (!mounted) return;
    setState(() => _arStatus = status);
  }

  void _startTiltListening() {
    _tiltSubscription?.cancel();
    _tiltSubscription = _tiltService.readings.listen(
      (reading) {
        if (!mounted || reading.isFlat == _isFlat) return;
        setState(() => _isFlat = reading.isFlat);
      },
      onError: (error) {
        debugPrint('Device tilt stream failed: $error');
      },
    );
  }

  Future<void> _handleMarkerScan(BarcodeCapture capture) async {
    if (_processingScan) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final match = _navMarkerPattern.firstMatch(raw.trim());
    if (match == null) {
      _processingScan = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not a navigation marker. Scan a NAV:N code.'),
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 1200));
      _processingScan = false;
      return;
    }

    _processingScan = true;
    final markerNumber = int.parse(match.group(1)!);
    try {
      await _scannerController.stop();
    } catch (_) {}

    _navigationService.startArNavigationFromMarker(markerNumber);

    if (!mounted) return;
    setState(() {
      _scannedMarker = markerNumber;
      _phase = _navigationService.mode == IndoorNavigationMode.complete
          ? _Phase.complete
          : _Phase.guiding;
    });

    if (_arStatus == ArSupportStatus.arSupported) {
      _startTiltListening();
    }
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    _arController = controller;
  }

  void _markArrived() {
    setState(() {
      _navigationService.markArrived();
      if (_navigationService.mode == IndoorNavigationMode.complete) {
        _phase = _Phase.complete;
      }
    });
  }

  Future<void> _restart() async {
    _tiltSubscription?.cancel();
    _arController?.dispose();
    _arController = null;
    _navigationService.reset();
    try {
      await _scannerController.start();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _phase = _Phase.scanMarker;
      _scannedMarker = null;
      _isFlat = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.scanMarker => _buildScannerView(),
      _Phase.guiding => _buildGuidingView(),
      _Phase.complete => _buildCompleteView(),
    };
  }

  Widget _buildScannerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleMarkerScan,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _ScannerOverlayPainter()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const _ModePill(
                        icon: Icons.qr_code_scanner,
                        label: 'AR Navigation',
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _NavigationCard(
                    title: 'Scan a navigation marker',
                    subtitle:
                        'Point at a NAV:1 - NAV:4 placard to set your starting point.',
                    child: SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidingView() {
    final canUseAr = _arStatus == ArSupportStatus.arSupported;
    if (!canUseAr || _isFlat) {
      return _buildMapGuidance(canUseAr: canUseAr);
    }
    return _buildArGuidance();
  }

  Widget _buildMapGuidance({required bool canUseAr}) {
    final target = _navigationService.currentTarget;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('AR Navigation'),
        actions: [
          if (canUseAr)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.screen_rotation_alt,
                color: AppColors.textMuted,
              ),
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
                  activeTargetId: target?.id,
                ),
              ),
            ),
            _NavigationCard(
              title: target?.name ?? 'Tour complete',
              subtitle: _instructionText,
              child: _NavigationActions(
                canMarkArrived: target != null,
                onArrived: _markArrived,
                onReset: _restart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArGuidance() {
    final target = _navigationService.currentTarget;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enablePlaneRenderer: false,
              enableTapRecognizer: false,
              enableUpdateListener: false,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ArArrowPainter(progress: _navigationService.activeIndex),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const _ModePill(
                        icon: Icons.view_in_ar,
                        label: 'AR Guide',
                      ),
                    ],
                  ),
                  const Spacer(),
                  _NavigationCard(
                    title: target?.name ?? 'Tour complete',
                    subtitle: _instructionText,
                    child: _NavigationActions(
                      canMarkArrived: target != null,
                      onArrived: _markArrived,
                      onReset: _restart,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    final markerLabel = _scannedMarker == null ? '' : ' from Marker $_scannedMarker';
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('AR Navigation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Icon(
                Icons.flag_circle,
                size: 88,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              _NavigationCard(
                title: 'Tour complete',
                subtitle: 'All remaining table stops$markerLabel are visited.',
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to map'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan another'),
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

  String get _instructionText {
    final target = _navigationService.currentTarget;
    if (target == null) return 'All table stops are complete.';
    final distance = _navigationService.currentLegDistanceMeters
        .toStringAsFixed(1);
    return 'Go to ${target.name} - $distance m from ${_navigationService.currentStartLabel}.';
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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
        color: const Color(0xF5FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.tileTitle.copyWith(color: AppColors.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppText.tileSubtitle.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _NavigationActions extends StatelessWidget {
  const _NavigationActions({
    required this.canMarkArrived,
    required this.onArrived,
    required this.onReset,
  });

  final bool canMarkArrived;
  final VoidCallback onArrived;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Restart'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canMarkArrived ? onArrived : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("I'm here"),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF5FDFBF7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textMain),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF5FDFBF7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = math.min(size.width, size.height) * 0.62;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: dim,
      height: dim,
    );
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const corner = 28.0;
    final path = Path()
      ..moveTo(rect.left, rect.top + corner)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + corner, rect.top)
      ..moveTo(rect.right - corner, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + corner)
      ..moveTo(rect.right, rect.bottom - corner)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - corner, rect.bottom)
      ..moveTo(rect.left + corner, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - corner);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArArrowPainter extends CustomPainter {
  _ArArrowPainter({required this.progress});

  final int progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final pulse = 1 + ((progress % 3) * 0.04);
    final arrowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path()
      ..moveTo(center.dx, center.dy - (118 * pulse))
      ..lineTo(center.dx + 58, center.dy - 42)
      ..lineTo(center.dx + 24, center.dy - 42)
      ..lineTo(center.dx + 24, center.dy + 96)
      ..lineTo(center.dx - 24, center.dy + 96)
      ..lineTo(center.dx - 24, center.dy - 42)
      ..lineTo(center.dx - 58, center.dy - 42)
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 8)), shadowPaint);
    canvas.drawPath(path, arrowPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final y = center.dy + 136 + (i * 34);
      final width = 90 - (i * 18);
      canvas.drawLine(
        Offset(center.dx - width / 2, y),
        Offset(center.dx + width / 2, y),
        linePaint,
      );
    }

    final compassPaint = Paint()
      ..color = const Color(0xF5FDFBF7)
      ..style = PaintingStyle.fill;
    final compassCenter = Offset(size.width - 58, size.height * 0.22);
    canvas.drawCircle(compassCenter, 28, compassPaint);

    final needlePaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const angle = -math.pi / 2;
    canvas.drawLine(
      compassCenter,
      compassCenter + Offset(math.cos(angle), math.sin(angle)) * 18,
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArArrowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
