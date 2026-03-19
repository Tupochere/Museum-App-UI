import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_tokens.dart';
import '../map/indoor_navigation_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum _AiMode { text, voice }

enum _VoiceState { idle, listening, thinking, speaking }

// ─────────────────────────────────────────────────────────────────────────────
// Mock data
// ─────────────────────────────────────────────────────────────────────────────
class _Mock {
  static const suggestions = [
    'Tell me about the Gule Wamkulu mask',
    'What ceremonies used this artifact?',
    'Guide me to the Hall of Ancestors',
    'When was this piece created?',
    'Explain Nyau traditions to me',
  ];

  static const responses = [
    'The Gule Wamkulu mask before you represents the spirit Kasiya Maliro. '
        'It was worn exclusively by initiated Nyau society members during funeral ceremonies '
        'to guide the departed into the ancestral realm. This piece dates to the late 19th century.',
    'This artifact was central to Chewa initiation rites. The Nyau society — '
        'a secret brotherhood — used these masks to bridge the world of the living and the '
        'ancestors. Only fully initiated men could wear them.',
    'The Hall of Ancestors is on Level 2, East Wing — about a 3-minute walk from here. '
        'It houses 43 artifacts spanning 300 years of Chewa heritage. Shall I navigate you there?',
    'This piece was crafted between 1880 and 1910, during a period when Chewa craftsmen '
        'were refining the symbolic vocabulary of Nyau masks. The red pigment comes from '
        'ground ochre sourced from the Dedza highlands.',
    'Nyau is a secret society of the Chewa, Mang\'anja, and Tumbuka peoples. Their '
        'ceremonies involve elaborate masked dances representing ancestral spirits, wild animals, '
        'and forces of nature. UNESCO inscribed Gule Wamkulu as Intangible Cultural Heritage in 2005.',
  ];

  static const voiceResponse =
      'The Gule Wamkulu mask you\'re standing in front of represents the '
      'spirit Kasiya Maliro. It was used in funeral ceremonies to guide the '
      'departed to the ancestral realm, and only initiated Nyau members could '
      'wear it. Would you like to know more about the Nyau society?';
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple message model
// ─────────────────────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  const _Msg({required this.text, required this.isUser});
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key});

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen>
    with TickerProviderStateMixin {
  // ── App state ─────────────────────────────────────────────────────────────
  _AiMode _mode = _AiMode.text;
  bool _tourMode = false;

  // ── Text mode ─────────────────────────────────────────────────────────────
  final _messages = <_Msg>[];
  final _scrollCtrl = ScrollController();
  int _responseIdx = 0;

  // ── Voice mode ────────────────────────────────────────────────────────────
  _VoiceState _voiceState = _VoiceState.idle;
  String _voiceText = '';

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _modeCtrl;
  late Animation<double> _modeFade;

  late AnimationController _sphereCtrl;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _textFadeCtrl;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _modeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _modeFade = CurvedAnimation(parent: _modeCtrl, curve: Curves.easeInOut);

    _sphereCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _textFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _textOpacity =
        CurvedAnimation(parent: _textFadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _modeCtrl.dispose();
    _sphereCtrl.dispose();
    _pulseCtrl.dispose();
    _textFadeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Mode switching ─────────────────────────────────────────────────────────
  void _enterVoice() {
    HapticFeedback.mediumImpact();
    setState(() {
      _mode = _AiMode.voice;
      _voiceState = _VoiceState.idle;
      _voiceText = '';
    });
    _modeCtrl.forward(from: 0);
    _textFadeCtrl.reset();
  }

  void _exitVoice() {
    _pulseCtrl
      ..stop()
      ..reset();
    _modeCtrl.reverse().then((_) {
      if (mounted) setState(() => _mode = _AiMode.text);
    });
  }

  // ── Voice state machine ────────────────────────────────────────────────────
  void _setVoiceState(_VoiceState s) {
    setState(() => _voiceState = s);
    if (s == _VoiceState.speaking) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl
        ..stop()
        ..reset();
    }
  }

  void _setVoiceText(String t) {
    _textFadeCtrl.reset();
    setState(() => _voiceText = t);
    if (t.isNotEmpty) _textFadeCtrl.forward();
  }

  void _handleOrbTap() {
    HapticFeedback.mediumImpact();
    switch (_voiceState) {
      case _VoiceState.idle:
        _setVoiceState(_VoiceState.listening);
        _setVoiceText('');
        _runDemoFlow();
      case _VoiceState.listening:
      case _VoiceState.thinking:
      case _VoiceState.speaking:
        _setVoiceState(_VoiceState.idle);
        _setVoiceText('');
    }
  }

  Future<void> _runDemoFlow() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _voiceState != _VoiceState.listening) return;
    _setVoiceState(_VoiceState.thinking);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _voiceState != _VoiceState.thinking) return;
    _setVoiceState(_VoiceState.speaking);
    _setVoiceText(_Mock.voiceResponse);
    await Future.delayed(const Duration(seconds: 7));
    if (!mounted) return;
    _setVoiceState(_VoiceState.idle);
    _setVoiceText('');
  }

  // ── Text mode messaging ────────────────────────────────────────────────────
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: text.trim(), isUser: true));
    });
    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          text: _Mock.responses[_responseIdx % _Mock.responses.length],
          isUser: false,
        ));
        _responseIdx++;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          _buildTextMode(),
          if (_mode == _AiMode.voice)
            FadeTransition(
              opacity: _modeFade,
              child: _buildVoiceMode(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT MODE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTextMode() {
    return Column(
      children: [
        _buildTopBar(),
        if (_tourMode) _buildTourBanner(),
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildChat(),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textMuted, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'AI Guide',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Tour toggle
            GestureDetector(
              onTap: () => setState(() => _tourMode = !_tourMode),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _tourMode
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _tourMode
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                  ),
                ),
                child: Icon(
                  Icons.route,
                  color: _tourMode ? AppColors.primary : AppColors.textMuted,
                  size: 17,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // History
            GestureDetector(
              onTap: _openTranscript,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Icon(Icons.history,
                    color: AppColors.textMuted, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.route, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tour Mode  •  Step 2 of 8',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Hall of Ancestors',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const IndoorNavigationScreen()),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Navigate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Spacer(flex: 2),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 30,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: 'mtengatenga\n',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                TextSpan(
                  text: 'AI guide',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ask about any artifact or begin your tour',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const Spacer(flex: 2),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'TRY ASKING',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _Mock.suggestions
                .map((s) => _SuggestionChip(
                      label: s,
                      onTap: () => _sendMessage(s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return m.isUser ? _buildUserBubble(m) : _buildAiBubble(m);
      },
    );
  }

  Widget _buildUserBubble(_Msg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Text(
            m.text,
            style: const TextStyle(
                color: AppColors.textMain, fontSize: 15, height: 1.45),
          ),
        ),
      ),
    );
  }

  Widget _buildAiBubble(_Msg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
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
                child: Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 12),
              ),
              const SizedBox(width: 6),
              const Text(
                'Mtengatenga Guide',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.text,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 16, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return _Composer(onSend: _sendMessage, onVoiceTap: _enterVoice);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOICE MODE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVoiceMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _voiceBg(),
          _voiceSphere(),
          if (_voiceText.isNotEmpty) _voiceResponseText(),
          _voiceTopBar(),
          _voiceBottomBar(),
        ],
      ),
    );
  }

  Widget _voiceBg() {
    final center =
        (_voiceState == _VoiceState.listening ||
                _voiceState == _VoiceState.thinking)
            ? const Color(0xFF001A26)
            : const Color(0xFF3A1F00);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.3,
          colors: [center, Colors.black],
          stops: const [0.0, 0.72],
        ),
      ),
    );
  }

  Widget _voiceSphere() {
    final hasText = _voiceText.isNotEmpty;
    final size = hasText ? 66.0 : 230.0;
    final align = hasText ? Alignment.bottomCenter : Alignment.center;
    final pad =
        hasText ? const EdgeInsets.only(bottom: 112) : EdgeInsets.zero;

    return AnimatedAlign(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOut,
      alignment: align,
      child: Padding(
        padding: pad,
        child: AnimatedBuilder(
          animation: Listenable.merge([_sphereCtrl, _pulseAnim]),
          builder: (_, __) {
            final scale = _voiceState == _VoiceState.speaking
                ? _pulseAnim.value
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _SpherePainter(
                    progress: _sphereCtrl.value,
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

  Widget _voiceResponseText() {
    return Positioned(
      top: 88,
      left: 26,
      right: 26,
      bottom: 180,
      child: FadeTransition(
        opacity: _textOpacity,
        child: SingleChildScrollView(
          child: Text(
            _voiceText,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 29,
              height: 1.38,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _voiceTopBar() {
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
                    color: Color(0xFF888888), size: 22),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _voiceBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: _voiceText.isEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Text(
                  switch (_voiceState) {
                    _VoiceState.listening => 'Listening...',
                    _VoiceState.thinking => 'Thinking...',
                    _ => 'Say something...',
                  },
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OrbBtn(icon: Icons.close, onTap: _exitVoice),
                  GestureDetector(
                    onTap: _handleOrbTap,
                    child: AnimatedBuilder(
                      animation: _sphereCtrl,
                      builder: (_, __) => SizedBox(
                        width: 72,
                        height: 72,
                        child: CustomPaint(
                          painter: _SpherePainter(
                            progress: _sphereCtrl.value,
                            state: _voiceState,
                            dense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _OrbBtn(
                    icon: _voiceState == _VoiceState.idle
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

  // ─────────────────────────────────────────────────────────────────────────
  // Transcript bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _openTranscript() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      showDragHandle: true,
      builder: (_) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Conversation',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet.',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AppColors.surfaceBorder, height: 1),
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          m.isUser
                              ? Icons.person_outline
                              : Icons.auto_awesome,
                          color: m.isUser
                              ? AppColors.textMuted
                              : AppColors.primary,
                          size: 18,
                        ),
                        title: Text(
                          m.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion chip
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, color: AppColors.textMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text composer (light)
// ─────────────────────────────────────────────────────────────────────────────
class _Composer extends StatefulWidget {
  const _Composer({required this.onSend, required this.onVoiceTap});

  final ValueChanged<String> onSend;
  final VoidCallback onVoiceTap;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.trim().isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSend(_ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.textMain.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              style: const TextStyle(
                  color: AppColors.textMain, fontSize: 15),
              maxLines: 5,
              minLines: 1,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Ask anything...',
                hintStyle:
                    TextStyle(color: AppColors.textMuted, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Attach placeholder
                const Icon(Icons.add,
                    color: AppColors.textMuted, size: 22),
                const Spacer(),
                // Mic placeholder
                const Icon(Icons.mic_none,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: 10),
                // Voice orb — launches voice mode
                GestureDetector(
                  onTap: widget.onVoiceTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq,
                        color: Colors.white, size: 20),
                  ),
                ),
                // Send — appears when text typed
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _hasText
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: _submit,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice circle button
// ─────────────────────────────────────────────────────────────────────────────
class _OrbBtn extends StatelessWidget {
  const _OrbBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Particle sphere painter — correct Y-axis rotation so sphere faces screen
// ─────────────────────────────────────────────────────────────────────────────
class _SpherePainter extends CustomPainter {
  final double progress;
  final _VoiceState state;
  final bool dense;

  const _SpherePainter({
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
    final count = dense ? 300 : 800;

    final isCool = state == _VoiceState.listening ||
        state == _VoiceState.thinking;

    // Warm palette (idle / speaking) — AppColors.primary orange
    const sphereWarm = Color(0xFFC05621);
    const sphereWarmBright = Color(0xFFFFCB8A);
    // Cool palette (listening / thinking)
    const sphereCool = Color(0xFF00AACC);
    const sphereCoolBright = Color(0xFF88EEFF);

    final base = isCool ? sphereCool : sphereWarm;
    final bright = isCool ? sphereCoolBright : sphereWarmBright;

    // Rotation speed around the vertical Y-axis
    final rotY = progress * 2 * pi * 0.35;

    for (int i = 0; i < count; i++) {
      // Random point on unit sphere using spherical coordinates
      final theta = rng.nextDouble() * 2 * pi; // azimuthal (longitude)
      final phi = acos(2 * rng.nextDouble() - 1); // polar (latitude)

      // 3-D position before rotation
      final x0 = radius * sin(phi) * cos(theta);
      final y0 = radius * cos(phi); // vertical axis — stays vertical
      final z0 = radius * sin(phi) * sin(theta);

      // Rotate around Y axis by rotY
      final x = cx + x0 * cos(rotY) + z0 * sin(rotY);
      final y = cy + y0; // Y unchanged by Y-axis rotation
      final z = -x0 * sin(rotY) + z0 * cos(rotY);

      // Depth-based size & opacity (z in [-radius, +radius])
      final depth = (z / radius + 1) / 2; // 0 = back, 1 = front
      final dotSize = (dense ? 1.2 : 1.8) * (0.3 + depth * 0.9);
      final opacity = (0.15 + depth * 0.85).clamp(0.0, 1.0);

      final isBright = rng.nextDouble() > 0.85;
      final color = (isBright ? bright : base).withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), dotSize, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.progress != progress || old.state != state;
}
