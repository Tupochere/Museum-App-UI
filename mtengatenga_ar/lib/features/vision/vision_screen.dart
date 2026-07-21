import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../services/translation_service.dart';
import '../../services/vision_service.dart';
import '../../theme/app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase enum
// ─────────────────────────────────────────────────────────────────────────────
enum _Phase { camera, analyzing, result }

// ─────────────────────────────────────────────────────────────────────────────
// Message model
// ─────────────────────────────────────────────────────────────────────────────
class _VisionMsg {
  final String text;
  final bool isUser;
  const _VisionMsg({required this.text, required this.isUser});
}

// ─────────────────────────────────────────────────────────────────────────────
// VisionScreen
// ─────────────────────────────────────────────────────────────────────────────
class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  // Services
  final _visionService = VisionService();
  final _translationService = GetIt.instance<TranslationService>();

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _flashOn = false;

  // Image state
  Uint8List? _capturedImageBytes;
  String? _imageBase64;

  // Phase
  _Phase _phase = _Phase.camera;

  // Conversation
  final _conversationHistory = <Map<String, String>>[];
  final _messages = <_VisionMsg>[];
  final _followUpCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isFollowUpLoading = false;
  bool _hasFollowUpText = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _followUpCtrl.addListener(() {
      final h = _followUpCtrl.text.trim().isNotEmpty;
      if (h != _hasFollowUpText) setState(() => _hasFollowUpText = h);
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _followUpCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();

      setState(() {
        _capturedImageBytes = bytes;
        _phase = _Phase.analyzing;
      });

      _imageBase64 = await VisionService.compressAndEncode(bytes);

      final prompt = _visionService.buildVisionPrompt(isFollowUp: false);
      final response = await _visionService.analyzeImage(
        imageBase64: _imageBase64!,
        prompt: prompt,
      );

      final displayText = await _translationService.translate(response);

      _conversationHistory.add({'role': 'model', 'content': response});

      if (!mounted) return;
      setState(() {
        _messages.add(_VisionMsg(text: displayText, isUser: false));
        _phase = _Phase.result;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Capture error: $e');
      if (!mounted) return;
      setState(() => _phase = _Phase.camera);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture image. Try again.')),
      );
    }
  }

  Future<void> _sendFollowUp() async {
    final question = _followUpCtrl.text.trim();
    if (question.isEmpty || _imageBase64 == null) return;

    _followUpCtrl.clear();
    setState(() {
      _messages.add(_VisionMsg(text: question, isUser: true));
      _isFollowUpLoading = true;
    });
    _scrollToBottom();

    _conversationHistory.add({'role': 'user', 'content': question});

    final prompt = _visionService.buildVisionPrompt(
      isFollowUp: true,
      userQuestion: question,
      history: _conversationHistory,
    );

    final response = await _visionService.analyzeImage(
      imageBase64: _imageBase64!,
      prompt: prompt,
    );

    final displayText = await _translationService.translate(response);
    _conversationHistory.add({'role': 'model', 'content': response});

    if (!mounted) return;
    setState(() {
      _messages.add(_VisionMsg(text: displayText, isUser: false));
      _isFollowUpLoading = false;
    });
    _scrollToBottom();
  }

  void _resetToCamera() {
    setState(() {
      _capturedImageBytes = null;
      _imageBase64 = null;
      _conversationHistory.clear();
      _messages.clear();
      _phase = _Phase.camera;
    });
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    _flashOn = !_flashOn;
    await _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_phase) {
        _Phase.camera => _buildCameraPhase(),
        _Phase.analyzing => _buildAnalyzingPhase(),
        _Phase.result => _buildResultPhase(),
      },
    );
  }

  // ── Phase 1: Camera ───────────────────────────────────────────────────────

  Widget _buildCameraPhase() {
    return Stack(
      children: [
        // Camera preview
        if (_isCameraReady && _cameraController != null)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instruction pill
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_enhance_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Point at any object',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Capture button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: GestureDetector(
                  onTap: _isCameraReady ? _captureAndAnalyze : null,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase 2: Analyzing ────────────────────────────────────────────────────

  Widget _buildAnalyzingPhase() {
    return Stack(
      children: [
        // Captured image as background
        if (_capturedImageBytes != null)
          Positioned.fill(
            child: Image.memory(
              _capturedImageBytes!,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.40),
              colorBlendMode: BlendMode.darken,
            ),
          ),

        // Loading overlay
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
      ],
    );
  }

  // ── Phase 3: Result ───────────────────────────────────────────────────────

  Widget _buildResultPhase() {
    return Column(
      children: [
        // Top bar with image thumbnail
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                if (_capturedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _capturedImageBytes!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Point & Learn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetToCamera,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'New',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Chat messages
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_isFollowUpLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isFollowUpLoading) {
                  return _buildThinkingBubble();
                }
                final m = _messages[i];
                return m.isUser ? _buildUserBubble(m) : _buildAiBubble(m);
              },
            ),
          ),
        ),

        // Follow-up input
        _buildFollowUpInput(),
      ],
    );
  }

  Widget _buildAiBubble(_VisionMsg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Guide',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Text(
              m.text,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(_VisionMsg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            m.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          const _ShimmerText('Thinking...'),
        ],
      ),
    );
  }

  Widget _buildFollowUpInput() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _followUpCtrl,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 15,
                ),
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _sendFollowUp(),
                decoration: const InputDecoration(
                  hintText: 'Ask a follow-up question...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _hasFollowUpText ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _hasFollowUpText ? _sendFollowUp : null,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
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
