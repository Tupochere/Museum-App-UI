import 'dart:async';
import 'dart:math' as math;

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';

import '../core/services/device_tilt_service.dart';
import '../core/services/indoor_navigation_service.dart';
import '../features/map/indoor_navigation_screen.dart';
import '../models/artifact.dart';
import '../services/supabase_service.dart';
import '../theme/app_tokens.dart';
import '../utils/ar_detector.dart';

class AdaptiveNavigationScreen extends StatefulWidget {
  const AdaptiveNavigationScreen({super.key, required this.artifactId});

  final String artifactId;

  @override
  State<AdaptiveNavigationScreen> createState() =>
      _AdaptiveNavigationScreenState();
}

class _AdaptiveNavigationScreenState extends State<AdaptiveNavigationScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final IndoorNavigationService _navigationService = IndoorNavigationService();
  final DeviceTiltService _tiltService = DeviceTiltService();

  StreamSubscription<DeviceTiltReading>? _tiltSubscription;
  ArCoreController? _arController;

  ArSupportStatus _arStatus = ArSupportStatus.checking;
  Artifact? _artifact;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isFlat = true;

  @override
  void initState() {
    super.initState();
    _loadNavigationContext();
  }

  @override
  void dispose() {
    _tiltSubscription?.cancel();
    _arController?.dispose();
    super.dispose();
  }

  Future<void> _loadNavigationContext() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _arStatus = ArSupportStatus.checking;
    });

    try {
      final results = await Future.wait<Object?>([
        ArDetector.checkAvailability(),
        _supabaseService.getArtifact(widget.artifactId),
      ]);

      if (!mounted) return;

      final arStatus = results[0]! as ArSupportStatus;
      final artifact = results[1] as Artifact?;
      final indoorArtifactId = _resolveIndoorArtifactId(artifact);

      if (indoorArtifactId != null) {
        _navigationService.startTourAfterArtifact(indoorArtifactId);
      } else {
        _navigationService.previewFullTour();
      }

      setState(() {
        _arStatus = arStatus;
        _artifact = artifact;
        _isLoading = false;
        _errorMessage = artifact == null
            ? 'No artifact found for QR code: ${widget.artifactId}'
            : null;
      });

      if (arStatus == ArSupportStatus.arSupported) {
        _startTiltListening();
      }
    } catch (error, stackTrace) {
      debugPrint('Adaptive navigation initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to prepare navigation. Check your connection.';
      });
    }
  }

  String? _resolveIndoorArtifactId(Artifact? artifact) {
    final candidates = [
      widget.artifactId,
      artifact?.id,
      artifact?.qrCode,
      artifact?.name,
    ].whereType<String>();

    for (final candidate in candidates) {
      final normalized = candidate.trim().toLowerCase();
      for (var index = 1; index <= 4; index++) {
        if (normalized == 'artifact_$index' ||
            normalized == 'artifact-$index' ||
            normalized == 'artifact $index' ||
            normalized == 'a$index' ||
            normalized.contains('artifact_$index') ||
            normalized.contains('artifact-$index') ||
            normalized.contains('artifact $index')) {
          return 'artifact_$index';
        }
      }
    }

    final digitMatch = RegExp(r'[1-4]').firstMatch(candidates.join(' '));
    if (digitMatch == null) return null;
    return 'artifact_${digitMatch.group(0)}';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _arStatus == ArSupportStatus.checking) {
      return _buildLoadingState();
    }

    if (_errorMessage != null || _artifact == null) {
      return _buildErrorState();
    }

    final canUseArGuidance = _arStatus == ArSupportStatus.arSupported;
    if (!canUseArGuidance || _isFlat) {
      return _buildMapGuidance(canUseArGuidance: canUseArGuidance);
    }

    return _buildArGuidance();
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpacing.lg),
              _NavigationCard(
                title: 'Navigation unavailable',
                subtitle: _errorMessage ?? 'Something went wrong.',
                child: ElevatedButton.icon(
                  onPressed: _loadNavigationContext,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapGuidance({required bool canUseArGuidance}) {
    final target = _navigationService.currentTarget;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        actions: [
          if (canUseArGuidance)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(Icons.screen_rotation_alt, color: AppColors.textMuted),
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
              title: _mapTitle(canUseArGuidance),
              subtitle: _instructionText,
              child: _NavigationActions(
                canMarkArrived: target != null,
                onArrived: _markArrived,
                onReset: _restartRoute,
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
                      onReset: _restartRoute,
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

  String _mapTitle(bool canUseArGuidance) {
    if (_navigationService.currentTarget == null) return 'Tour complete';
    if (!canUseArGuidance) return '2D Map Guide';
    return '2D Map Guide';
  }

  String get _instructionText {
    final target = _navigationService.currentTarget;
    if (target == null) {
      return 'All table stops are complete.';
    }

    final distance = _navigationService.currentLegDistanceMeters
        .toStringAsFixed(1);
    return 'Go to ${target.name} - $distance m from ${_navigationService.currentStartLabel}.';
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    _arController = controller;
  }

  void _markArrived() {
    setState(_navigationService.markArrived);
  }

  void _restartRoute() {
    final indoorArtifactId = _resolveIndoorArtifactId(_artifact);
    setState(() {
      if (indoorArtifactId != null) {
        _navigationService.startTourAfterArtifact(indoorArtifactId);
      } else {
        _navigationService.previewFullTour();
      }
    });
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
    final angle = -math.pi / 2;
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
