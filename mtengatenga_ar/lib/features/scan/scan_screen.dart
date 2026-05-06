import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/domain/entities/artifact.model.dart';
import '../../core/domain/repositories/artifact_repository.dart';
import '../../core/models/ui_models.dart';
import '../../core/services/scan_history_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/ticket_gate.dart';
import '../../core/ui/states/state_view.dart';
import '../../screens/adaptive_navigation_screen.dart';
import '../../services/search_service.dart';
import '../../services/vision_service.dart';
import '../../theme/app_tokens.dart';
import '../ai_guide/ai_guide_screen.dart';
import '../artifact/artifact_details_screen.dart';
import '../artifact/artifact_not_found_screen.dart';
import 'scan_help_screen.dart';
import 'scan_history_screen.dart';

/// Minimum similarity score to consider a vision-to-artifact match valid
/// when falling back to describe-then-semantic-search.
const double _visionMatchThreshold = 0.55;

/// Minimum confidence to accept a match from the dedicated
/// `/identify-artifact` Gemini Vision endpoint.
const double _identifyArtifactConfidenceThreshold = 0.6;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final MobileScannerController _cameraController;

  // ── Mode ────────────────────────────────────────────────────────────────
  ScanMode _mode = ScanMode.qr;
  bool _isSwitchingMode = false;

  // ── QR state ────────────────────────────────────────────────────────────
  bool _flashOn = false;
  ScanViewState _state = ScanViewState.searching;
  Artifact? _scannedArtifact;
  bool _isProcessing = false;
  bool _hasNavigatedToDetails = false;
  String? _lastScanError;
  String? _lastScannedValue;

  // ── Vision state ────────────────────────────────────────────────────────
  CameraController? _visionCamera;
  bool _isVisionCameraReady = false;
  Uint8List? _capturedImageBytes;
  String? _visionDescription;
  final _visionService = VisionService();

  IArtifactRepository? get _artifactRepository {
    final getIt = ServiceLocator.instance;
    if (!getIt.isRegistered<IArtifactRepository>()) return null;
    return getIt<IArtifactRepository>();
  }

  ScanHistoryService? get _scanHistoryService {
    final getIt = ServiceLocator.instance;
    if (!getIt.isRegistered<ScanHistoryService>()) return null;
    return getIt<ScanHistoryService>();
  }

  SearchService? get _searchService {
    final getIt = ServiceLocator.instance;
    if (!getIt.isRegistered<SearchService>()) return null;
    return getIt<SearchService>();
  }

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController.dispose();
    _visionCamera?.dispose();
    super.dispose();
  }

  // ── Mode switching ────────────────────────────────────────────────────────

  Future<void> _switchMode(ScanMode newMode) async {
    if (newMode == _mode || _isSwitchingMode) return;
    setState(() => _isSwitchingMode = true);

    try {
      if (newMode == ScanMode.vision) {
        // Stop QR camera, start vision camera
        try {
          await _cameraController.stop();
        } catch (_) {}

        await _initVisionCamera();
        setState(() {
          _mode = ScanMode.vision;
          _state = ScanViewState.visionCapturing;
          _capturedImageBytes = null;
          _visionDescription = null;

        });
      } else {
        // Stop vision camera, start QR camera
        await _disposeVisionCamera();
        try {
          await _cameraController.start();
        } catch (_) {}

        setState(() {
          _mode = ScanMode.qr;
          _state = ScanViewState.searching;
          _scannedArtifact = null;
          _isProcessing = false;
          _hasNavigatedToDetails = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isSwitchingMode = false);
    }
  }

  Future<void> _initVisionCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _visionCamera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _visionCamera!.initialize();
      if (_flashOn) {
        await _visionCamera!.setFlashMode(FlashMode.torch);
      }
      if (mounted) setState(() => _isVisionCameraReady = true);
    } catch (e) {
      debugPrint('Vision camera init error: $e');
      if (mounted) setState(() => _state = ScanViewState.permissionDenied);
    }
  }

  Future<void> _disposeVisionCamera() async {
    _isVisionCameraReady = false;
    try {
      await _visionCamera?.dispose();
    } catch (_) {}
    _visionCamera = null;
  }

  // ── Vision capture & match ────────────────────────────────────────────────

  Future<void> _captureAndMatch() async {
    if (_visionCamera == null || !_visionCamera!.value.isInitialized) return;

    final navigator = Navigator.of(context);

    try {
      final xFile = await _visionCamera!.takePicture();
      final bytes = await xFile.readAsBytes();

      setState(() {
        _capturedImageBytes = bytes;
        _state = ScanViewState.visionAnalyzing;
      });

      final imageBase64 = await VisionService.compressAndEncode(bytes);

      // 1) Direct artifact identification via Gemini Vision against the catalog.
      final identification = await _visionService.identifyArtifact(
        imageBase64: imageBase64,
      );
      if (!mounted) return;

      if (identification != null &&
          identification.hasMatch &&
          identification.confidence >= _identifyArtifactConfidenceThreshold) {
        final repo = _artifactRepository;
        if (repo != null) {
          final artifact = await repo.getArtifactById(identification.artifactId);
          if (!mounted) return;

          if (artifact != null) {
            setState(() => _state = ScanViewState.visionFound);

            try {
              await _scanHistoryService?.addScan(artifact);
            } catch (_) {}

            await navigator.push(
              MaterialPageRoute(
                builder: (_) => ArtifactDetailsScreen(artifact: artifact),
              ),
            );
            if (mounted) _resetVision();
            return;
          }
        }
      }

      // 2) Fallback — describe the image and run semantic search on the description.
      final fallbackDescription = identification?.description.isNotEmpty == true
          ? identification!.description
          : await _visionService.analyzeImage(
              imageBase64: imageBase64,
              prompt: _visionService.buildVisionPrompt(isFollowUp: false),
            );
      if (!mounted) return;

      if (fallbackDescription.startsWith('Sorry') ||
          fallbackDescription.startsWith('Cloud Function URL')) {
        setState(() {
          _visionDescription = fallbackDescription;
          _state = ScanViewState.visionNoMatch;
        });
        return;
      }

      _visionDescription = fallbackDescription;

      final search = _searchService;
      if (search != null) {
        final results = await search.search(fallbackDescription);
        if (!mounted) return;

        if (results.isNotEmpty &&
            results.first.similarity >= _visionMatchThreshold) {
          final repo = _artifactRepository;
          if (repo != null) {
            final artifact = await repo.getArtifactById(results.first.id);
            if (!mounted) return;

            if (artifact != null) {
              setState(() => _state = ScanViewState.visionFound);

              try {
                await _scanHistoryService?.addScan(artifact);
              } catch (_) {}

              await navigator.push(
                MaterialPageRoute(
                  builder: (_) => ArtifactDetailsScreen(artifact: artifact),
                ),
              );
              if (mounted) _resetVision();
              return;
            }
          }
        }
      }

      if (mounted) {
        setState(() => _state = ScanViewState.visionNoMatch);
      }
    } catch (e) {
      debugPrint('Vision capture error: $e');
      if (!mounted) return;
      setState(() {
        _visionDescription = 'Failed to analyze image. Please try again.';
        _state = ScanViewState.visionNoMatch;
      });
    }
  }

  void _resetVision() {
    setState(() {
      _capturedImageBytes = null;
      _visionDescription = null;
      _state = ScanViewState.visionCapturing;
    });
  }

  // ── QR handling (unchanged logic) ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final permissionState = _state == ScanViewState.permissionDenied;
    final isVision = _mode == ScanMode.vision;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (!permissionState) ...[
            if (!isVision)
              Positioned.fill(
                child: MobileScanner(
                  controller: _cameraController,
                  onDetect: _handleBarcodeScan,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Text(
                        'Camera Error: ${error.errorCode}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              )
            else if (_isVisionCameraReady && _visionCamera != null)
              Positioned.fill(
                child: _capturedImageBytes != null
                    ? Image.memory(
                        _capturedImageBytes!,
                        fit: BoxFit.cover,
                        color: _state == ScanViewState.visionAnalyzing
                            ? Colors.black.withValues(alpha: 0.40)
                            : null,
                        colorBlendMode: _state == ScanViewState.visionAnalyzing
                            ? BlendMode.darken
                            : null,
                      )
                    : CameraPreview(_visionCamera!),
              )
            else if (isVision)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],

          if (!permissionState && !isVision)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.20)),
            ),

          // Analyzing overlay
          if (_state == ScanViewState.visionAnalyzing)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    _ShimmerText('Analyzing...'),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _TopArea(
                  flashOn: _flashOn,
                  onBack: () => Navigator.pop(context),
                  onFlash: _toggleFlash,
                  mode: _mode,
                  onModeChanged: _switchMode,
                  isSwitching: _isSwitchingMode,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // QR scan frame (only in QR mode)
                      if (!isVision)
                        Opacity(
                          opacity: permissionState ? 0.30 : 1,
                          child: _ScanFrame(controller: _scanController),
                        ),

                      // Permission prompt
                      if (_state == ScanViewState.permissionDenied)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          child: PermissionPromptCard(
                            title: 'Camera Access Needed',
                            message:
                                'Allow camera access so the app can recognize artifacts and AR triggers.',
                            actionLabel: 'Enable Camera',
                            onAction: () async {
                              if (_mode == ScanMode.qr) {
                                await _cameraController.start();
                              } else {
                                await _initVisionCamera();
                              }
                              if (!mounted) return;
                              setState(() => _state = _mode == ScanMode.qr
                                  ? ScanViewState.searching
                                  : ScanViewState.visionCapturing);
                            },
                          ),
                        ),

                      // QR found card
                      if (_state == ScanViewState.found &&
                          _scannedArtifact != null)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.24,
                          child: _FoundCard(
                            artifactName: _scannedArtifact!.name,
                            onView: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ArtifactDetailsScreen(
                                    artifact: _scannedArtifact!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // QR no match card
                      if (_state == ScanViewState.noMatch)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.24,
                          child: _NoMatchCard(
                            onRetry: _restartScanning,
                            scannedValue: _lastScannedValue,
                            onOpenFallback: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ArtifactNotFoundScreen(),
                                ),
                              );
                            },
                          ),
                        ),

                      // Vision no-match card
                      if (_state == ScanViewState.visionNoMatch &&
                          _visionDescription != null)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.18,
                          child: _VisionNoMatchCard(
                            description: _visionDescription!,
                            onRetry: _resetVision,
                            onAskGuide: () => TicketGate.navigate(
                              context,
                              () => const AiGuideScreen(),
                            ),
                          ),
                        ),

                      // Status pill
                      Positioned(
                        bottom: h * 0.15,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildStatusPill(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom area: history/help for QR, capture button for vision
                if (isVision)
                  _CaptureBar(
                    onCapture: (_state == ScanViewState.visionCapturing &&
                            _isVisionCameraReady)
                        ? _captureAndMatch
                        : null,
                    onHistory: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScanHistoryScreen(),
                        ),
                      );
                    },
                    onHelp: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ScanHelpScreen()),
                      );
                    },
                  )
                else
                  _BottomBar(
                    onHistory: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScanHistoryScreen(),
                        ),
                      );
                    },
                    onHelp: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ScanHelpScreen()),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    switch (_state) {
      case ScanViewState.searching:
        return const _SearchingPill(key: ValueKey('searching'));
      case ScanViewState.found:
        return const _StatusPill(
          icon: Icons.check_circle,
          label: 'ARTIFACT FOUND',
          color: Color(0xFF2E7D32),
        );
      case ScanViewState.error:
        return _RetryPill(label: 'SCAN FAILED', onRetry: _restartScanning);
      case ScanViewState.permissionDenied:
        return const _StatusPill(
          icon: Icons.block,
          label: 'CAMERA OFF',
          color: Color(0xFFC62828),
        );
      case ScanViewState.lowLight:
        return const _StatusPill(
          icon: Icons.wb_incandescent_outlined,
          label: 'LOW LIGHT',
          color: Color(0xFFE2725B),
        );
      case ScanViewState.noMatch:
        return _RetryPill(label: 'NO MATCH', onRetry: _restartScanning);
      case ScanViewState.visionCapturing:
        return const _StatusPill(
          key: ValueKey('visionReady'),
          icon: Icons.camera_enhance_outlined,
          label: 'READY',
          color: AppColors.primary,
        );
      case ScanViewState.visionAnalyzing:
        return const _SearchingPill(key: ValueKey('visionAnalyzing'));
      case ScanViewState.visionFound:
        return const _StatusPill(
          icon: Icons.check_circle,
          label: 'ARTIFACT IDENTIFIED',
          color: Color(0xFF2E7D32),
        );
      case ScanViewState.visionNoMatch:
        return _RetryPill(label: 'NO MATCH', onRetry: _resetVision);
    }
  }

  void _toggleFlash() async {
    _flashOn = !_flashOn;
    if (_mode == ScanMode.qr) {
      _cameraController.toggleTorch();
    } else if (_visionCamera != null) {
      await _visionCamera!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
    }
    setState(() {});
  }

  void _restartScanning() {
    setState(() {
      _state = ScanViewState.searching;
      _scannedArtifact = null;
      _isProcessing = false;
      _hasNavigatedToDetails = false;
      _lastScanError = null;
      _lastScannedValue = null;
    });
    _cameraController.start();
  }

  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final qrCode = _extractQrValue(capture.barcodes);
    if (qrCode == null) return;

    debugPrint('QR detected: "$qrCode"');
    _lastScannedValue = qrCode;

    final repository = _artifactRepository;
    if (repository == null) {
      setState(() {
        _lastScanError =
            'Data layer not initialized. Restart app and verify .env.';
        _state = ScanViewState.error;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data layer not initialized. Check .env SUPABASE_URL and SUPABASE_ANON_KEY.',
            ),
          ),
        );
      }
      _isProcessing = false;
      return;
    }

    _isProcessing = true;

    try {
      final artifact = await repository.getArtifactByQrCode(qrCode);

      if (!mounted) return;

      if (artifact != null) {
        debugPrint(
          'QR matched artifact: id=${artifact.id}, qr=${artifact.qrCode}, name=${artifact.name}',
        );
        setState(() {
          _scannedArtifact = artifact;
          _state = ScanViewState.found;
        });

        try {
          await _scanHistoryService?.addScan(artifact);
        } catch (_) {}

        try {
          await _cameraController.stop();
        } catch (_) {}

        if (!_hasNavigatedToDetails && mounted) {
          _hasNavigatedToDetails = true;
          if (!mounted) return;
          try {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdaptiveNavigationScreen(artifactId: qrCode),
              ),
            );
          } catch (_) {}
          if (mounted) {
            _restartScanning();
          }
        }
      } else {
        setState(() => _state = ScanViewState.noMatch);
        if (mounted) {
          final preview = qrCode.length > 80
              ? '${qrCode.substring(0, 80)}...'
              : qrCode;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('No match for QR: $preview')));
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _restartScanning();
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Scan lookup failed for "$qrCode": $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _lastScanError = _friendlyError(error);
        _state = ScanViewState.error;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan failed: $_lastScanError')));

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _restartScanning();
      });
    } finally {
      _isProcessing = false;
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SUPABASE_URL')) {
      return 'Missing SUPABASE_URL in .env';
    }
    if (text.contains('SUPABASE_ANON_KEY')) {
      return 'Missing SUPABASE_ANON_KEY in .env';
    }
    if (text.contains('not registered inside GetIt')) {
      return 'Services not initialized';
    }
    return text;
  }

  String? _extractQrValue(List<Barcode> barcodes) {
    for (final barcode in barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) return raw;

      final display = barcode.displayValue?.trim();
      if (display != null && display.isNotEmpty) return display;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _TopArea extends StatelessWidget {
  const _TopArea({
    required this.flashOn,
    required this.onBack,
    required this.onFlash,
    required this.mode,
    required this.onModeChanged,
    required this.isSwitching,
  });

  final bool flashOn;
  final VoidCallback onBack;
  final VoidCallback onFlash;
  final ScanMode mode;
  final ValueChanged<ScanMode> onModeChanged;
  final bool isSwitching;

  @override
  Widget build(BuildContext context) {
    final isQr = mode == ScanMode.qr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        18,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
              _CircleIconButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off,
                onTap: onFlash,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xD9FDFBF7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  isQr ? 'Point camera at QR code' : 'Point at any object',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isQr
                      ? 'Align the code within the frame'
                      : 'Tap capture to identify',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                _ModeToggle(
                  mode: mode,
                  onChanged: isSwitching ? null : onModeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final ScanMode mode;
  final ValueChanged<ScanMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceBorder,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'QR Code',
            icon: Icons.qr_code_scanner,
            active: mode == ScanMode.qr,
            onTap: onChanged != null ? () => onChanged!(ScanMode.qr) : null,
          ),
          _ToggleChip(
            label: 'Object',
            icon: Icons.camera_enhance_outlined,
            active: mode == ScanMode.vision,
            onTap:
                onChanged != null ? () => onChanged!(ScanMode.vision) : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onHistory, required this.onHelp});
  final VoidCallback onHistory;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        12,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            label: 'History',
            icon: Icons.collections_outlined,
            onTap: onHistory,
          ),
          _ActionButton(label: 'Help', icon: Icons.help_outline, onTap: onHelp),
        ],
      ),
    );
  }
}

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({
    required this.onCapture,
    required this.onHistory,
    required this.onHelp,
  });

  final VoidCallback? onCapture;
  final VoidCallback onHistory;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        12,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            label: 'History',
            icon: Icons.collections_outlined,
            onTap: onHistory,
          ),
          GestureDetector(
            onTap: onCapture,
            child: Opacity(
              opacity: onCapture != null ? 1.0 : 0.4,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ActionButton(
            label: 'Help',
            icon: Icons.help_outline,
            onTap: onHelp,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xD9FDFBF7),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMain),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xD9FDFBF7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textMain),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 256,
      height: 256,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0x0DFDFBF7),
                border: Border.all(color: const Color(0x4DD4A017), width: 1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) {
                final y = (262) * controller.value - 3;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: y,
                  child: Container(height: 3, color: const Color(0xFFD4A017)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingPill extends StatefulWidget {
  const _SearchingPill({super.key});

  @override
  State<_SearchingPill> createState() => _SearchingPillState();
}

class _SearchingPillState extends State<_SearchingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BasePill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Opacity(
                opacity: 0.30 + 0.70 * _pulse.value,
                child: const Icon(
                  Icons.circle,
                  size: 10,
                  color: Color(0xFFD4A017),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          const Text(
            'SEARCHING...',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _BasePill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryPill extends StatelessWidget {
  const _RetryPill({required this.label, required this.onRetry});
  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BasePill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _BasePill extends StatelessWidget {
  const _BasePill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.artifactName, required this.onView});

  final String artifactName;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return _OverlayCard(
      title: artifactName,
      subtitle: 'Artifact detected and ready to open.',
      actionLabel: 'View',
      onAction: onView,
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard({
    required this.onRetry,
    required this.onOpenFallback,
    this.scannedValue,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenFallback;
  final String? scannedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          const Text(
            'No matching artifact found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
          if (scannedValue != null && scannedValue!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              scannedValue!.length > 60
                  ? '${scannedValue!.substring(0, 60)}...'
                  : scannedValue!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpenFallback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Need Help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisionNoMatchCard extends StatelessWidget {
  const _VisionNoMatchCard({
    required this.description,
    required this.onRetry,
    required this.onAskGuide,
  });

  final String description;
  final VoidCallback onRetry;
  final VoidCallback onAskGuide;

  @override
  Widget build(BuildContext context) {
    // Truncate to ~3 sentences for display
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+'));
    final preview =
        sentences.take(3).join(' ').trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'What I See',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAskGuide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: const Text('Ask AI Guide'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.museum_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText(this.text);
  final String text;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 3.0 * _ctrl.value, 0),
              end: Alignment(-1.0 + 3.0 * _ctrl.value + 1.0, 0),
              colors: const [
                AppColors.textMuted,
                AppColors.primary,
                AppColors.textMuted,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: const TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
