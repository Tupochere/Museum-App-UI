import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';
import 'scan_help_screen.dart';
import 'scan_history_screen.dart';

enum ScanUiState { searching, found, error }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  Timer? _simulateFoundTimer;
  Timer? _autoOpenTimer;
  bool _didNavigateToDetails = false;
  bool _flashOn = false;

  // UI only: toggle states for demo
  ScanUiState _state = ScanUiState.searching;

  static const _bgUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA-QdLXYVLcupowILko324Kow061FlJG19lwvli15SKT4z1k_2QOKiyYqmkAZBBu5ZXvkIxasMZdDQnOjnRW3AkuAw35MTJbv8KBEBBEBAAmRK84WHyNj_QgMJRyXB87UE2S_8sj9Frzrt01OcoKGDgQr-NxLe-xX-XpY-9adoOk44nx6-YZqIKb9QPBHTmtprFexVhdIVTN9L40p5Y_XJ9keomSVFMBLk2U-X2LF35RPVmX9FP4LhL6zDV6Ln1WJDW9tBZyh7J2TsX';

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _restartScanSimulation(fromInit: true);
  }

  @override
  void dispose() {
    _simulateFoundTimer?.cancel();
    _autoOpenTimer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              _bgUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.10),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.06))),

          SafeArea(
            child: Column(
              children: [
                _TopArea(
                  flashOn: _flashOn,
                  onBack: () => Navigator.pop(context),
                  onFlash: () => setState(() => _flashOn = !_flashOn),
                  // UI-only “state switcher” (remove later)
                  onLongPressTitle: () {
                    setState(() {
                      _state = ScanUiState.values[
                          (_state.index + 1) % ScanUiState.values.length];
                    });
                  },
                ),

                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ScanFrame(controller: _scanController),

                      // Middle status (depends on state)
                      Positioned(
                        bottom: h * 0.15,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _buildStatusPill(),
                        ),
                      ),

                      // Found overlay card
                      if (_state == ScanUiState.found)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.24,
                          child: _FoundCard(
                            onView: _openArtifactDetails,
                          ),
                        ),
                    ],
                  ),
                ),

                _BottomBar(
                  onHistory: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
                    );
                  },
                  onHelp: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanHelpScreen()),
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
      case ScanUiState.searching:
        return const _SearchingPill(key: ValueKey('searching'));
      case ScanUiState.found:
        return const _SuccessPill(key: ValueKey('found'));
      case ScanUiState.error:
        return _ErrorPill(
          key: const ValueKey('error'),
          onRetry: _restartScanSimulation,
        );
    }
  }

  void _restartScanSimulation({bool fromInit = false}) {
    _simulateFoundTimer?.cancel();
    _autoOpenTimer?.cancel();
    _didNavigateToDetails = false;
    if (fromInit) {
      _state = ScanUiState.searching;
    } else {
      setState(() => _state = ScanUiState.searching);
    }

    _simulateFoundTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _state = ScanUiState.found);

      _autoOpenTimer = Timer(const Duration(seconds: 1), () {
        _openArtifactDetails();
      });
    });
  }

  void _openArtifactDetails() {
    if (!mounted || _didNavigateToDetails) return;
    _didNavigateToDetails = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute(builder: (_) => const ArtifactDetailsScreen()),
    )
        .then((_) {
      if (!mounted) return;
      _restartScanSimulation();
    });
  }
}

class _TopArea extends StatelessWidget {
  const _TopArea({
    required this.flashOn,
    required this.onBack,
    required this.onFlash,
    required this.onLongPressTitle,
  });

  final bool flashOn;
  final VoidCallback onBack;
  final VoidCallback onFlash;

  // UI-only debug gesture (remove later)
  final VoidCallback onLongPressTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.35),
            Colors.transparent,
          ],
        ),
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
          GestureDetector(
            onLongPress: onLongPressTitle, // UI-only
            child: const _InstructionCard(),
          ),
        ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 18, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.28),
            Colors.black.withOpacity(0.10),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HistoryButton(onTap: onHistory),
          _HelpButton(onTap: onHelp),
        ],
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
        decoration: BoxDecoration(
          color: const Color(0xD9FDFBF7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.40)),
          boxShadow: const [
            BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x14000000)),
          ],
        ),
        child: Icon(icon, color: AppColors.textMain),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
        boxShadow: const [
          BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x1A000000)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Point camera at artifact',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Align the object within the frame',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain.withOpacity(0.72),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxWidth >= 420) ? 320.0 : 256.0;

        return SizedBox(
          width: size,
          height: size,
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
                    final y = (size + 6) * controller.value - 3;
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: y,
                      child: Container(
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4A017),
                          boxShadow: [
                            BoxShadow(blurRadius: 14, color: Color(0xCCD4A017)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const _CornerBrackets(),
                Center(
                  child: Opacity(
                    opacity: 0.40,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(height: 1, color: Color(0xFFFDFBF7)),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Container(width: 1, color: Color(0xFFFDFBF7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFD4A017);
    const thickness = 3.0;
    const corner = 24.0;
    const radius = 10.0;

    Widget cornerBox({
      required Alignment align,
      required bool top,
      required bool left,
    }) {
      return Align(
        alignment: align,
        child: Container(
          width: corner,
          height: corner,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular((top && left) ? radius : 0),
              topRight: Radius.circular((top && !left) ? radius : 0),
              bottomLeft: Radius.circular((!top && left) ? radius : 0),
              bottomRight: Radius.circular((!top && !left) ? radius : 0),
            ),
            border: Border(
              top: top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              bottom: !top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              left: left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              right: !left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        cornerBox(align: Alignment.topLeft, top: true, left: true),
        cornerBox(align: Alignment.topRight, top: true, left: false),
        cornerBox(align: Alignment.bottomLeft, top: false, left: true),
        cornerBox(align: Alignment.bottomRight, top: false, left: false),
      ],
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
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
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
              final opacity = 0.35 + (0.65 * _pulse.value);
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017).withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          const Text(
            'SEARCHING...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPill extends StatelessWidget {
  const _SuccessPill({super.key});

  @override
  Widget build(BuildContext context) {
    return _BasePill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
          SizedBox(width: 10),
          Text(
            'ARTIFACT FOUND',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  const _ErrorPill({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BasePill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 16, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          const Text(
            'NO QR DETECTED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
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
        border: Border.all(color: Colors.white.withOpacity(0.20)),
        boxShadow: const [
          BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x1A000000)),
        ],
      ),
      child: child,
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.onView});
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFBF7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x1F000000)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.museum_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngoni Shield',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap to view artifact details',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xD9FDFBF7),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
              boxShadow: const [
                BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x1A000000)),
              ],
            ),
            child: const Icon(Icons.collections_outlined, color: AppColors.textMain),
          ),
          const SizedBox(height: 6),
          const Text(
            'History',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFDFBF7),
              shadows: [Shadow(blurRadius: 8, color: Color(0x66000000))],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFE2725B),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: const [
            BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x33E2725B)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Help',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
