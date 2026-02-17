import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';
import '../artifact/artifact_not_found_screen.dart';
import 'scan_help_screen.dart';
import 'scan_history_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  Timer? _simulateFoundTimer;
  bool _flashOn = false;
  ScanViewState _state = ScanViewState.searching;

  static const _bgUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA-QdLXYVLcupowILko324Kow061FlJG19lwvli15SKT4z1k_2QOKiyYqmkAZBBu5ZXvkIxasMZdDQnOjnRW3AkuAw35MTJbv8KBEBBEBAAmRK84WHyNj_QgMJRyXB87UE2S_8sj9Frzrt01OcoKGDgQr-NxLe-xX-XpY-9adoOk44nx6-YZqIKb9QPBHTmtprFexVhdIVTN9L40p5Y_XJ9keomSVFMBLk2U-X2LF35RPVmX9FP4LhL6zDV6Ln1WJDW9tBZyh7J2TsX';

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _restartScanSimulation();
  }

  @override
  void dispose() {
    _simulateFoundTimer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final permissionState = _state == ScanViewState.permissionDenied;

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
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.10))),
          SafeArea(
            child: Column(
              children: [
                _TopArea(
                  flashOn: _flashOn,
                  onBack: () => Navigator.pop(context),
                  onFlash: () => setState(() => _flashOn = !_flashOn),
                  onLongPressTitle: _cycleUiStates,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: permissionState ? 0.30 : 1,
                        child: _ScanFrame(controller: _scanController),
                      ),
                      if (_state == ScanViewState.permissionDenied)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          child: PermissionPromptCard(
                            title: 'Camera Access Needed',
                            message: 'Allow camera access so the app can recognize artifacts and AR triggers.',
                            actionLabel: 'Enable Camera',
                            onAction: () => setState(() => _state = ScanViewState.searching),
                          ),
                        ),
                      if (_state == ScanViewState.found)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.24,
                          child: _FoundCard(
                            onView: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ArtifactDetailsScreen()),
                              );
                            },
                          ),
                        ),
                      if (_state == ScanViewState.noMatch)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: h * 0.24,
                          child: _NoMatchCard(
                            onRetry: _restartScanSimulation,
                            onOpenFallback: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ArtifactNotFoundScreen()),
                              );
                            },
                          ),
                        ),
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
      case ScanViewState.searching:
        return const _SearchingPill(key: ValueKey('searching'));
      case ScanViewState.found:
        return const _StatusPill(icon: Icons.check_circle, label: 'ARTIFACT FOUND', color: Color(0xFF2E7D32));
      case ScanViewState.error:
        return _RetryPill(
          label: 'SCAN FAILED',
          onRetry: _restartScanSimulation,
        );
      case ScanViewState.permissionDenied:
        return const _StatusPill(icon: Icons.block, label: 'CAMERA OFF', color: Color(0xFFC62828));
      case ScanViewState.lowLight:
        return const _StatusPill(icon: Icons.wb_incandescent_outlined, label: 'LOW LIGHT', color: Color(0xFFE2725B));
      case ScanViewState.noMatch:
        return _RetryPill(label: 'NO MATCH', onRetry: _restartScanSimulation);
    }
  }

  void _restartScanSimulation() {
    _simulateFoundTimer?.cancel();
    setState(() => _state = ScanViewState.searching);
    _simulateFoundTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _state = ScanViewState.found);
    });
  }

  void _cycleUiStates() {
    setState(() {
      _state = ScanViewState.values[(_state.index + 1) % ScanViewState.values.length];
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
  final VoidCallback onLongPressTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
              _CircleIconButton(icon: flashOn ? Icons.flash_on : Icons.flash_off, onTap: onFlash),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onLongPress: onLongPressTitle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xD9FDFBF7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Text(
                    'Point camera at artifact',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textMain),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Align the object within the frame',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(label: 'History', icon: Icons.collections_outlined, onTap: onHistory),
          _ActionButton(label: 'Help', icon: Icons.help_outline, onTap: onHelp),
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
                  child: Container(
                    height: 3,
                    color: const Color(0xFFD4A017),
                  ),
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

class _SearchingPillState extends State<_SearchingPill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
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
                child: const Icon(Icons.circle, size: 10, color: Color(0xFFD4A017)),
              );
            },
          ),
          const SizedBox(width: 10),
          const Text('SEARCHING...', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain)),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain)),
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
  const _FoundCard({required this.onView});
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return _OverlayCard(
      title: 'Ngoni Shield',
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
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenFallback;

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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textMain),
          ),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.museum_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
