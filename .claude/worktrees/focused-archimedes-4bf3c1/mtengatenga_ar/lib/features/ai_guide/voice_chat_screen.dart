import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Perplexity-style Voice Chat Mode
/// 
/// Dependencies to add to pubspec.yaml:
/// ```yaml
/// dependencies:
///   speech_to_text: ^6.6.0        # For speech recognition
///   flutter_tts: ^4.0.2           # For text-to-speech
///   permission_handler: ^11.3.0   # For mic permissions
///   http: ^1.2.0                  # For API calls
/// ```
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => const VoiceChatScreen(),
///   ));

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: VoiceChatScreen(),
  ));
}

// ---------------------------------------------------------------------------
// State enum
// ---------------------------------------------------------------------------
enum VoiceState { idle, listening, thinking, speaking }

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------
class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  VoiceState _voiceState = VoiceState.idle;
  String _displayText = '';

  // Particle sphere controller
  late AnimationController _sphereController;

  // Pulse animation for speaking state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Text fade controller
  late AnimationController _textController;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _sphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textOpacity = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _sphereController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _setState(VoiceState state) {
    setState(() => _voiceState = state);
    if (state == VoiceState.speaking) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _setDisplayText(String text) {
    _textController.reset();
    setState(() => _displayText = text);
    _textController.forward();
  }

  // Simulated demo tap handler — replace with real STT/TTS logic
  void _handleMicTap() {
    HapticFeedback.mediumImpact();
    switch (_voiceState) {
      case VoiceState.idle:
        _setState(VoiceState.listening);
        _setDisplayText('');
        // TODO: start speech_to_text here
        // After recognition → _setState(VoiceState.thinking)
        // After API response → _setState(VoiceState.speaking); _setDisplayText(response)
        _demoFlow(); // remove in production
        break;
      case VoiceState.listening:
      case VoiceState.thinking:
      case VoiceState.speaking:
        _setState(VoiceState.idle);
        _setDisplayText('');
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Demo flow (remove when wiring real STT/TTS/API)
  // ---------------------------------------------------------------------------
  Future<void> _demoFlow() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _setState(VoiceState.thinking);
    _setDisplayText('');
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _setState(VoiceState.speaking);
    _setDisplayText(
      "That's totally fine. If anything comes to mind, just let me know. "
      "In the meantime, how's your day going?",
    );
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    _setState(VoiceState.idle);
    _setDisplayText('');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          _buildBackground(),
          // Particle sphere (center when no text, bottom bar when text showing)
          _buildSphereArea(),
          // Response text
          if (_displayText.isNotEmpty) _buildResponseText(),
          // Top bar
          _buildTopBar(context),
          // Bottom controls
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background gradient — shifts by state
  // ---------------------------------------------------------------------------
  Widget _buildBackground() {
    final Color warmCenter = _voiceState == VoiceState.idle ||
            _voiceState == VoiceState.speaking
        ? const Color(0xFF5C3A00)
        : const Color(0xFF002233);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [warmCenter, Colors.black],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Particle sphere
  // ---------------------------------------------------------------------------
  Widget _buildSphereArea() {
    final bool hasText = _displayText.isNotEmpty;
    final double sphereSize = hasText ? 60.0 : 220.0;
    final Alignment alignment = hasText ? Alignment.bottomCenter : Alignment.center;
    final EdgeInsets padding = hasText
        ? const EdgeInsets.only(bottom: 100)
        : EdgeInsets.zero;

    return AnimatedAlign(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: AnimatedBuilder(
          animation: Listenable.merge([_sphereController, _pulseAnimation]),
          builder: (_, __) {
            final scale = _voiceState == VoiceState.speaking
                ? _pulseAnimation.value
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: sphereSize,
                height: sphereSize,
                child: CustomPaint(
                  painter: _ParticleSpherePainter(
                    progress: _sphereController.value,
                    state: _voiceState,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Response / prompt text
  // ---------------------------------------------------------------------------
  Widget _buildResponseText() {
    return Positioned(
      top: 80,
      left: 24,
      right: 24,
      child: FadeTransition(
        opacity: _textOpacity,
        child: Text(
          _displayText,
          style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 30,
            height: 1.35,
            fontFamily: 'serif',
            fontWeight: FontWeight.w300,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — settings icon
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Color(0xFF888888), size: 26),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar — close / sphere button / mic
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Say something..." hint
              AnimatedOpacity(
                opacity: _voiceState == VoiceState.listening ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _voiceState == VoiceState.listening
                      ? 'Listening...'
                      : _voiceState == VoiceState.thinking
                          ? 'Thinking...'
                          : 'Say something...',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.maybePop(context),
                  ),

                  // Main orb button (tap to start/stop)
                  GestureDetector(
                    onTap: _handleMicTap,
                    child: AnimatedBuilder(
                      animation: _sphereController,
                      builder: (_, __) => SizedBox(
                        width: 70,
                        height: 70,
                        child: CustomPaint(
                          painter: _ParticleSpherePainter(
                            progress: _sphereController.value,
                            state: _voiceState,
                            dense: true,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Keyboard / mic toggle
                  _CircleButton(
                    icon: _voiceState == VoiceState.idle
                        ? Icons.mic_none_outlined
                        : Icons.keyboard_alt_outlined,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable circle button
// ---------------------------------------------------------------------------
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2A2A),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Particle sphere painter
// ---------------------------------------------------------------------------
class _ParticleSpherePainter extends CustomPainter {
  final double progress;
  final VoiceState state;
  final bool dense;

  _ParticleSpherePainter({
    required this.progress,
    required this.state,
    this.dense = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;
    final int count = dense ? 300 : 800;

    // Color by state
    final Color baseColor = state == VoiceState.listening ||
            state == VoiceState.thinking
        ? const Color(0xFF00AACC)
        : const Color(0xFFFF8C00);
    final Color brightColor = state == VoiceState.listening ||
            state == VoiceState.thinking
        ? const Color(0xFF88EEFF)
        : const Color(0xFFFFEEAA);

    for (int i = 0; i < count; i++) {
      // Spherical coords
      final double theta = rng.nextDouble() * 2 * pi;
      final double phi = acos(2 * rng.nextDouble() - 1);

      // Animate rotation
      final double animTheta = theta + progress * 2 * pi * 0.3;

      final double x = cx + radius * sin(phi) * cos(animTheta);
      final double y = cy + radius * sin(phi) * sin(animTheta) * 0.4;
      final double z = radius * cos(phi);

      // Depth-based sizing / opacity
      final double depth = (z / radius + 1) / 2; // 0..1
      final double dotSize = (dense ? 1.2 : 1.8) * (0.4 + depth * 0.8);
      final double opacity = 0.2 + depth * 0.8;

      // Occasional bright particle
      final bool bright = rng.nextDouble() > 0.85;
      final Color color = (bright ? brightColor : baseColor)
          .withOpacity(opacity.clamp(0, 1));

      canvas.drawCircle(
        Offset(x, y),
        dotSize,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticleSpherePainter old) =>
      old.progress != progress || old.state != state;
}
