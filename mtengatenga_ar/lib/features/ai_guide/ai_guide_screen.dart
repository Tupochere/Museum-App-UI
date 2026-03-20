import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/domain/entities/artifact.model.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_tokens.dart';
import '../map/indoor_navigation_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum _AiMode { text, voice }

enum _VoiceState { idle, listening, thinking, speaking }

// ─────────────────────────────────────────────────────────────────────────────
// Task 1 — Fake Amplitude Engine
// ─────────────────────────────────────────────────────────────────────────────
class _AmplitudeEngine {
  static double getValue(double t, _VoiceState state) {
    switch (state) {
      case _VoiceState.idle:
        return 0.0;
      case _VoiceState.thinking:
        return 0.08 + 0.06 * sin(t * 1.2);
      case _VoiceState.listening:
        return (0.3 +
                0.4 * sin(t * 3.7) +
                0.2 * sin(t * 7.1) +
                0.1 * sin(t * 13.3))
            .clamp(0.0, 1.0);
      case _VoiceState.speaking:
        final beat = sin(t * pi / 0.4);
        final base = 0.45 + 0.3 * beat;
        final texture = 0.15 * sin(t * 9.2);
        final breathe = 0.1 * sin(t * 0.7);
        return (base + texture + breathe).clamp(0.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulse ring data class (Task 11b)
// ─────────────────────────────────────────────────────────────────────────────
class _PulseRing {
  final double birthTime;
  _PulseRing(this.birthTime);
}

// ─────────────────────────────────────────────────────────────────────────────
// Message model
// ─────────────────────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  const _Msg({required this.text, required this.isUser});
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level pseudo-noise helper (Task 2b)
// ─────────────────────────────────────────────────────────────────────────────
double _sineNoise(int seed, double t) {
  final s = seed * 127 + 1;
  return sin(s * 0.317 + t * 1.7) * cos(s * 0.573 + t * 0.9);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key, this.artifact});

  final Artifact? artifact;

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen>
    with TickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final _geminiService = GeminiService();
  final _supabaseService = SupabaseService();
  late final FlutterTts _tts;

  // ── Conversation ──────────────────────────────────────────────────────────
  final _conversationHistory = <Map<String, String>>[];
  bool _isTyping = false;

  // ── Offline ────────────────────────────────────────────────────────────────
  bool _isOffline = false;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  // ── Tour ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _tourStops = [];
  int _currentTourStopIndex = 0;
  String _currentTourName = '';

  // ── Mode ──────────────────────────────────────────────────────────────────
  _AiMode _mode = _AiMode.text;
  bool _tourMode = false;

  // ── Text mode ─────────────────────────────────────────────────────────────
  final _messages = <_Msg>[];
  final _scrollCtrl = ScrollController();

  // ── Voice mode core ────────────────────────────────────────────────────────
  _VoiceState _voiceState = _VoiceState.idle;
  bool _hasResponseText = false;
  bool _isExiting = false;

  // ── Word streaming (Task 4) ────────────────────────────────────────────────
  List<String> _words = [];
  int _revealedWordCount = 0;
  Timer? _wordTimer;
  final ScrollController _responseScrollCtrl = ScrollController();

  // ── Amplitude / beat (Tasks 1, 9e, 12a) ───────────────────────────────────
  double _cachedAmplitude = 0.0;
  int _ampFrameCount = 0;
  double _beatStrength = 0.0;
  double _beatDecayStart = 0.0;
  double _lastSpeakingAmp = 0.0;

  // ── Pulse rings (Task 11b) ─────────────────────────────────────────────────
  final List<_PulseRing> _pulseRings = [];
  double _lastAmplitude = 0.0;

  // ── Thinking dots (Task 17) ────────────────────────────────────────────────
  bool _thinkingDotsVisible = false;

  // ── Particle count (Task 9d) ───────────────────────────────────────────────
  late int _particleCount;

  // ── Animation controllers ──────────────────────────────────────────────────
  // Existing (keep)
  late AnimationController _sphereCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _textFadeCtrl;
  late AnimationController _modeCtrl;
  late Animation<double> _modeFade;
  late Animation<double> _textOpacity;

  // New (Tasks 1, 2c, 3a, 10b, 14)
  late AnimationController _timeCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _stateTransitionCtrl;
  late AnimationController _thinkCtrl;
  late AnimationController _orbEntryCtrl;
  late Animation<double> _orbEntryScale;
  late Animation<double> _orbEntryOpacity;

  // ─────────────────────────────────────────────────────────────────────────
  // initState
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _particleCount = _resolveParticleCount();

    // Existing controllers
    _sphereCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _textFadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _textOpacity =
        CurvedAnimation(parent: _textFadeCtrl, curve: Curves.easeIn);
    _modeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _modeFade = CurvedAnimation(parent: _modeCtrl, curve: Curves.easeInOut);

    // New controllers
    _timeCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _stateTransitionCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _thinkCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _orbEntryCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _orbEntryScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_orbEntryCtrl);

    _orbEntryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _orbEntryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _timeCtrl.addListener(_onTimeTick);

    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.50);
    _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) _resetToIdle();
    });

    _checkConnectivity();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      final offline = result == ConnectivityResult.none;
      if (mounted && offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = result == ConnectivityResult.none);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // dispose
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sphereCtrl.dispose();
    _pulseCtrl.dispose();
    _textFadeCtrl.dispose();
    _modeCtrl.dispose();
    _timeCtrl.dispose();
    _breathCtrl.dispose();
    _stateTransitionCtrl.dispose();
    _thinkCtrl.dispose();
    _orbEntryCtrl.dispose();
    _scrollCtrl.dispose();
    _responseScrollCtrl.dispose();
    _wordTimer?.cancel();
    _connectivitySub?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 9d — Particle count heuristic
  // ─────────────────────────────────────────────────────────────────────────
  int _resolveParticleCount() {
    try {
      return Platform.numberOfProcessors <= 4 ? 500 : 800;
    } catch (_) {
      return 800;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 9e — Time tick: amplitude + beat + pulse ring updates
  // ─────────────────────────────────────────────────────────────────────────
  void _onTimeTick() {
    if (!mounted) return;
    _ampFrameCount++;
    final elapsed = _timeCtrl.value * 60.0;
    if (_ampFrameCount % 2 == 0) {
      _cachedAmplitude = _AmplitudeEngine.getValue(elapsed, _voiceState);
      _updateBeatDetection(elapsed);
      _checkPulseEmit(elapsed);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 12a — Beat detection
  // ─────────────────────────────────────────────────────────────────────────
  void _updateBeatDetection(double elapsed) {
    if (_voiceState != _VoiceState.speaking) {
      _beatStrength = 0.0;
      return;
    }
    final amp = _cachedAmplitude;
    if (amp > 0.60 && _lastSpeakingAmp <= 0.60) {
      _beatStrength = 1.0;
      _beatDecayStart = elapsed;
    }
    final beatAge = elapsed - _beatDecayStart;
    _beatStrength = (1.0 - beatAge / 0.25).clamp(0.0, 1.0);
    _lastSpeakingAmp = amp;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 11b — Pulse ring emission
  // ─────────────────────────────────────────────────────────────────────────
  void _checkPulseEmit(double elapsed) {
    if (_voiceState != _VoiceState.listening) return;
    final amp = _cachedAmplitude;
    if (amp > 0.65 && _lastAmplitude <= 0.65) {
      _pulseRings.add(_PulseRing(elapsed));
      if (_pulseRings.length > 4) _pulseRings.removeAt(0);
    }
    _lastAmplitude = amp;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 3a — Centralised state change
  // ─────────────────────────────────────────────────────────────────────────
  void _onStateChanged(_VoiceState newState) {
    setState(() => _voiceState = newState);

    if (newState == _VoiceState.speaking) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl
        ..stop()
        ..reset();
    }

    switch (newState) {
      case _VoiceState.idle:
        _stateTransitionCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut);
        _thinkCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
        setState(() => _thinkingDotsVisible = false);

      case _VoiceState.listening:
        // Stay warm — no color shift during listening
        _stateTransitionCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
        _thinkCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
        setState(() => _thinkingDotsVisible = false);

      case _VoiceState.thinking:
        // Full teal shift + hollow ring contraction
        _stateTransitionCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut);
        _thinkCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOut);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _voiceState == _VoiceState.thinking) {
            setState(() => _thinkingDotsVisible = true);
          }
        });

      case _VoiceState.speaking:
        // Keep teal — mini orb at bottom center is teal
        _stateTransitionCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut);
        _thinkCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
        setState(() => _thinkingDotsVisible = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 3b — Sequenced orb-shrink → text-stream
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _enterSpeakingState(String text) async {
    _onStateChanged(_VoiceState.speaking);
    setState(() => _hasResponseText = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textFadeCtrl.forward();
    _streamWords(text);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 4 — Word streaming
  // ─────────────────────────────────────────────────────────────────────────
  void _streamWords(String fullText) {
    _cancelWordStream();
    setState(() {
      _words = fullText.split(' ');
      _revealedWordCount = 0;
    });
    _scheduleNextWord();
  }

  void _scheduleNextWord() {
    if (_revealedWordCount >= _words.length) return;
    final word = _words[_revealedWordCount];
    final delay = word.length <= 3
        ? const Duration(milliseconds: 110)
        : word.length <= 6
            ? const Duration(milliseconds: 160)
            : const Duration(milliseconds: 210);
    _wordTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _revealedWordCount++);
      // Auto-scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_responseScrollCtrl.hasClients) {
          _responseScrollCtrl.animateTo(
            _responseScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
      _scheduleNextWord();
    });
  }

  void _cancelWordStream() {
    _wordTimer?.cancel();
    _wordTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reset to idle (Tasks 4e, 5)
  // ─────────────────────────────────────────────────────────────────────────
  void _resetToIdle() {
    _cancelWordStream();
    _onStateChanged(_VoiceState.idle);
    _textFadeCtrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _words = [];
          _revealedWordCount = 0;
          _hasResponseText = false;
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 14 — Voice mode entry
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _enterVoice() async {
    HapticFeedback.mediumImpact();
    setState(() => _mode = _AiMode.voice);
    _modeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _orbEntryCtrl.forward();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 15 — Voice mode exit
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _exitVoice() async {
    setState(() => _isExiting = true);
    _orbEntryCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _modeCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _mode = _AiMode.text;
      _isExiting = false;
    });
    _resetToIdle();
    _orbEntryCtrl.reset();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Orb tap handler
  // ─────────────────────────────────────────────────────────────────────────
  void _handleOrbTap() {
    HapticFeedback.mediumImpact();
    switch (_voiceState) {
      case _VoiceState.idle:
        _onStateChanged(_VoiceState.listening);
        _pulseRings.clear();
        _runDemoFlow();
      case _VoiceState.listening:
      case _VoiceState.thinking:
      case _VoiceState.speaking:
        _resetToIdle();
    }
  }

  Future<void> _runDemoFlow() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _voiceState != _VoiceState.listening) return;
    _onStateChanged(_VoiceState.thinking);

    final prompt = widget.artifact != null
        ? 'Give me a brief, engaging introduction to this artifact.'
        : 'Welcome me to Mtengatenga Museum and give me a brief overview of what I can explore here.';

    final response = await _geminiService.voiceQuery(widget.artifact, prompt);

    if (!mounted || _voiceState != _VoiceState.thinking) return;
    await _enterSpeakingState(response);
    _tts.speak(response);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text mode messaging
  // ─────────────────────────────────────────────────────────────────────────
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    if (_isOffline) return;
    final userText = text.trim();
    setState(() {
      _messages.add(_Msg(text: userText, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    _geminiService
        .chatAboutArtifact(
          widget.artifact ?? GeminiService.museumGuideArtifact,
          userText,
          List.from(_conversationHistory),
        )
        .then((response) {
      if (!mounted) return;
      _conversationHistory.add({'role': 'user', 'content': userText});
      _conversationHistory.add({'role': 'model', 'content': response});
      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(0, 2);
      }
      setState(() {
        _isTyping = false;
        _messages.add(_Msg(text: response, isUser: false));
      });
      _scrollToBottom();
    });
  }

  List<String> _buildSuggestions() {
    final artifact = widget.artifact;
    if (artifact == null) {
      return const [
        'What can I explore here?',
        'Tell me about Chewa culture',
        'Start a guided tour',
        'What are the featured artifacts?',
        'Explain Nyau traditions',
      ];
    }
    final category = artifact.category?.toUpperCase() ?? '';
    if (category.contains('MUSICAL')) {
      return [
        'How was the ${artifact.name} played?',
        'What ceremonies used this instrument?',
        'Tell me about its materials',
        'When was this piece created?',
        'How does it connect to Chewa spirituality?',
      ];
    }
    if (category.contains('WEAPON') || category.contains('TOOL')) {
      return [
        'Who used the ${artifact.name}?',
        'How was it made?',
        'What was its purpose in ceremonies?',
        'Tell me about its period: ${artifact.period ?? 'unknown'}',
        'How does it compare to modern equivalents?',
      ];
    }
    if (category.contains('POTTERY') || category.contains('CERAMIC')) {
      return [
        'How was this pottery made?',
        'What was it used for?',
        'Tell me about the patterns and symbols',
        'Who made vessels like this?',
        'What does it reveal about daily life?',
      ];
    }
    return [
      'Tell me about the ${artifact.name}',
      'What ceremonies used this artifact?',
      'When was this piece created?',
      'What cultural significance does it hold?',
      'Tell me more about ${artifact.period ?? 'this period'}',
    ];
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

  Future<void> _showTourSelector() async {
    final tours = await _supabaseService.getActiveTours();
    if (!mounted) return;
    if (tours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active tours available.')),
      );
      return;
    }
    if (tours.length == 1) {
      await _loadTour(tours.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Select a Tour',
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final tour in tours)
            ListTile(
              leading: const Icon(Icons.route, color: AppColors.primary),
              title: Text(
                tour['name'] as String? ?? '',
                style: const TextStyle(
                    color: AppColors.textMain, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${tour['duration_minutes']} min  •  ${tour['difficulty']}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _loadTour(tour);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _loadTour(Map<String, dynamic> tour) async {
    final stops = await _supabaseService.getTourStops(tour['id'] as String);
    if (!mounted) return;
    setState(() {
      _tourMode = true;
      _tourStops = stops;
      _currentTourStopIndex = 0;
      _currentTourName = tour['name'] as String? ?? '';
    });
    if (stops.isNotEmpty) {
      final narration = stops.first['narration'] as String? ?? '';
      if (narration.isNotEmpty) {
        _sendMessage('Starting tour: $narration');
      }
    }
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
            FadeTransition(opacity: _modeFade, child: _buildVoiceMode()),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TEXT MODE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTextMode() {
    return Column(
      children: [
        _buildTopBar(),
        if (_isOffline) _buildOfflineBanner(),
        if (_tourMode) _buildTourBanner(),
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildChat(),
        ),
        if (_isTyping) _buildTypingIndicator(),
        _Composer(
          onSend: _isOffline ? (_) {} : _sendMessage,
          onVoiceTap: _enterVoice,
          disabled: _isOffline,
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF3CD),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, size: 14, color: Color(0xFF856404)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline Mode — AI guide requires internet. Viewing cached content.',
              style: TextStyle(
                color: Color(0xFF856404),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 12),
            ),
            const SizedBox(width: 8),
            const Text(
              'Thinking…',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
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
            GestureDetector(
              onTap: () {
                if (_tourMode) {
                  setState(() {
                    _tourMode = false;
                    _tourStops = [];
                    _currentTourStopIndex = 0;
                    _currentTourName = '';
                  });
                } else {
                  _showTourSelector();
                }
              },
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
                child: Icon(Icons.route,
                    color: _tourMode ? AppColors.primary : AppColors.textMuted,
                    size: 17),
              ),
            ),
            const SizedBox(width: 6),
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
    final hasStops = _tourStops.isNotEmpty;
    final stepLabel = hasStops
        ? 'Tour Mode  •  Step ${_currentTourStopIndex + 1} of ${_tourStops.length}'
        : 'Tour Mode  •  Loading…';
    final stopLabel = hasStops
        ? (_tourStops[_currentTourStopIndex]['artifact_id'] as String? ?? '')
        : _currentTourName;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stepLabel,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(stopLabel,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const IndoorNavigationScreen())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Navigate',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
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
              style: TextStyle(fontSize: 30, letterSpacing: -0.5, height: 1.2),
              children: [
                TextSpan(
                  text: 'mtengatenga\n',
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w300),
                ),
                TextSpan(
                  text: 'AI guide',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800),
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
              child: Text('TRY ASKING',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildSuggestions()
                .map((s) => _SuggestionChip(
                    label: s, onTap: () => _sendMessage(s)))
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
              maxWidth: MediaQuery.of(context).size.width * 0.78),
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
          child: Text(m.text,
              style: const TextStyle(
                  color: AppColors.textMain, fontSize: 15, height: 1.45)),
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
              const Text('Mtengatenga Guide',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(m.text,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }

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
                const Text('Conversation',
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Done',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet.',
                        style: TextStyle(color: AppColors.textMuted)))
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
                        title: Text(m.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 14)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // VOICE MODE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildVoiceMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _voiceBg(),
          _voiceSphereArea(),
          if (_words.isNotEmpty) _voiceResponseText(),
          _voiceTopBar(),
          _voiceIndicators(),
          _voiceBottomBar(),
        ],
      ),
    );
  }

  // Task 8 — Enhanced background gradient
  Widget _voiceBg() {
    final isCool = _voiceState == _VoiceState.listening ||
        _voiceState == _VoiceState.thinking;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: isCool ? 1.1 : 1.0,
          colors: isCool
              ? const [
                  Color(0xFF002233),
                  Color(0xFF001020),
                  Colors.black,
                ]
              : const [
                  Color(0xFF3A1F00),
                  Color(0xFF1A0D00),
                  Colors.black,
                ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }

  // Tasks 2, 9c, 14, 15 — Sphere (hidden when response text is showing)
  Widget _voiceSphereArea() {
    // When text is visible, the bottom bar mini orb is the only orb shown.
    // Hide this one to avoid two overlapping orbs.
    if (_hasResponseText) return const SizedBox.shrink();

    const orbSize = 230.0;
    const align = Alignment.center;
    const pad = EdgeInsets.zero;

    return Align(
      alignment: align,
      child: Padding(
        padding: pad,
        child: SizedBox(
          width: orbSize * 2.2,
          height: orbSize * 2.2,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _sphereCtrl, _breathCtrl, _timeCtrl,
                _stateTransitionCtrl, _thinkCtrl, _orbEntryCtrl,
              ]),
              builder: (_, __) {
                final elapsed = _timeCtrl.value * 60.0;

                // Breathing scale (Task 2c)
                final breathScale = switch (_voiceState) {
                  _VoiceState.idle =>
                    0.97 + 0.03 * _breathCtrl.value,
                  _VoiceState.listening =>
                    0.93 + 0.10 * _breathCtrl.value,
                  _VoiceState.thinking =>
                    0.95 + 0.02 * _breathCtrl.value,
                  _VoiceState.speaking =>
                    0.94 +
                        0.08 * _breathCtrl.value +
                        _cachedAmplitude * 0.06,
                };

                // Color blend warm↔cool (Task 6)
                // idle/listening → 0.0 (warm), thinking/speaking → 1.0 (teal)
                final stateBlend = _stateTransitionCtrl.value;

                // Entry progress for materialization
                final entryProg = _isExiting
                    ? _orbEntryCtrl.value
                    : _orbEntryCtrl.value;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse rings layer (Task 11b)
                    if (_voiceState == _VoiceState.listening)
                      CustomPaint(
                        painter: _PulseRingPainter(
                          rings: List.from(_pulseRings),
                          elapsed: elapsed,
                          maxRadius: orbSize / 2,
                        ),
                        size: Size(orbSize * 2.2, orbSize * 2.2),
                      ),
                    // Main sphere
                    Transform.scale(
                      scale: _orbEntryScale.value,
                      child: Opacity(
                        opacity: _orbEntryOpacity.value.clamp(0.0, 1.0),
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: orbSize,
                            height: orbSize,
                            child: CustomPaint(
                              painter: _SpherePainter(
                                progress: _sphereCtrl.value,
                                state: _voiceState,
                                amplitude: _cachedAmplitude,
                                elapsed: elapsed,
                                breathScale: breathScale,
                                stateBlend: stateBlend,
                                thinkingContraction: _thinkCtrl.value,
                                beatStrength: _beatStrength,
                                entryProgress: entryProg,
                                isExiting: _isExiting,
                                idleTiltX: _voiceState == _VoiceState.idle
                                    ? _breathCtrl.value
                                    : 0.0,
                                particleCount: _particleCount,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Task 18 — Scrollable response text with fade mask
  Widget _voiceResponseText() {
    return Positioned(
      top: 88,
      left: 26,
      right: 26,
      bottom: 200,
      child: FadeTransition(
        opacity: _textOpacity,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.75, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _responseScrollCtrl,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: _buildStreamingText(),
            ),
          ),
        ),
      ),
    );
  }

  // Task 4b — Word-by-word RichText renderer
  Widget _buildStreamingText() {
    if (_words.isEmpty) return const SizedBox.shrink();
    final isComplete = _revealedWordCount >= _words.length;
    final spans = <InlineSpan>[];
    for (int i = 0; i < _revealedWordCount; i++) {
      final word = _words[i];
      final isLastActive = i == _revealedWordCount - 1 && !isComplete;
      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(
          fontSize: isLastActive ? 38 : 34,
          fontWeight:
              isLastActive ? FontWeight.w700 : FontWeight.w300,
          color: isLastActive
              ? Colors.white
              : const Color(0xFF888888),
          height: 1.30,
          letterSpacing: -0.5,
        ),
      ));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 80),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(
        key: ValueKey(_revealedWordCount),
        child: RichText(text: TextSpan(children: spans)),
      ),
    );
  }

  // Task 19 — Settings icon (frosted pill, fades during speaking)
  Widget _voiceTopBar() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: _voiceState == _VoiceState.speaking ? 0.15 : 0.75,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 16),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.8),
                ),
                child: Icon(Icons.settings_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.70)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tasks 7, 13, 17 — Waveform / dots / status label
  Widget _voiceIndicators() {
    return Positioned(
      bottom: 168,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: switch (_voiceState) {
              _VoiceState.listening => KeyedSubtree(
                  key: const ValueKey('wave'),
                  child: _buildMicWaveform(),
                ),
              _VoiceState.thinking when _thinkingDotsVisible =>
                KeyedSubtree(
                  key: const ValueKey('dots'),
                  child: _buildThinkingDots(),
                ),
              _ => const SizedBox(height: 28, key: ValueKey('empty')),
            },
          ),
          const SizedBox(height: 10),
          // Task 7 — crossfading status label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              switch (_voiceState) {
                _VoiceState.listening => 'Listening...',
                _VoiceState.thinking => 'Thinking...',
                _VoiceState.speaking => '',
                _VoiceState.idle => 'Say something...',
              },
              key: ValueKey(_voiceState),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Task 13 — 5-bar mic waveform
  Widget _buildMicWaveform() {
    return AnimatedBuilder(
      animation: _timeCtrl,
      builder: (_, __) {
        final t = _timeCtrl.value * 60.0;
        final scale = _cachedAmplitude.clamp(0.3, 1.0);
        final h1 = 6.0 + (10.0 * scale) * ((sin(t * 8.0 + 0.0) + 1) / 2);
        final h2 = 6.0 + (14.0 * scale) * ((sin(t * 9.3 + 1.0) + 1) / 2);
        final h3 = 6.0 + (14.0 * scale) * ((sin(t * 7.6 + 2.1) + 1) / 2);
        final h4 = 6.0 + (12.0 * scale) * ((sin(t * 10.1 + 3.2) + 1) / 2);
        final h5 = 6.0 + (10.0 * scale) * ((sin(t * 8.7 + 4.0) + 1) / 2);
        return SizedBox(
          width: 35,
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _bar(h1, 3.0),
              const SizedBox(width: 5),
              _bar(h2, 3.0),
              const SizedBox(width: 5),
              _bar(h3, 3.0),
              const SizedBox(width: 5),
              _bar(h4, 3.0),
              const SizedBox(width: 5),
              _bar(h5, 3.0),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double h, double w) => Container(
        width: w,
        height: h.clamp(4.0, 28.0),
        decoration: BoxDecoration(
          color: const Color(0xFF00AACC).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(w / 2),
        ),
      );

  // Task 17 — 3-dot thinking indicator
  Widget _buildThinkingDots() {
    return AnimatedBuilder(
      animation: _timeCtrl,
      builder: (_, __) {
        final t = _timeCtrl.value * 60.0;
        final d1 = (sin(t * 4.0 + 0.0) + 1) / 2;
        final d2 = (sin(t * 4.0 + 1.2) + 1) / 2;
        final d3 = (sin(t * 4.0 + 2.4) + 1) / 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _thinkDot(d1),
            const SizedBox(width: 8),
            _thinkDot(d2),
            const SizedBox(width: 8),
            _thinkDot(d3),
          ],
        );
      },
    );
  }

  Widget _thinkDot(double phase) {
    final s = 5.0 + phase * 4.0;
    final op = 0.25 + phase * 0.65;
    final dy = -phase * 5.0;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00AACC).withValues(alpha: op),
        ),
      ),
    );
  }

  // Task 5 — Bottom bar (buttons fade during speaking)
  Widget _voiceBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OrbBtn(icon: Icons.close, onTap: _exitVoice),
              // Center: mini teal orb during speaking, hint text otherwise
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _voiceState == _VoiceState.speaking
                    ? GestureDetector(
                        key: const ValueKey('mini-orb'),
                        onTap: _handleOrbTap,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: AnimatedBuilder(
                            animation:
                                Listenable.merge([_sphereCtrl, _timeCtrl]),
                            builder: (_, __) => CustomPaint(
                              painter: _SpherePainter(
                                progress: _sphereCtrl.value,
                                state: _voiceState,
                                amplitude: _cachedAmplitude,
                                elapsed: _timeCtrl.value * 60.0,
                                breathScale: 1.0,
                                stateBlend: _stateTransitionCtrl.value,
                                dense: true,
                                particleCount: 300,
                              ),
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('hint-text'),
                        onTap: _handleOrbTap,
                        child: SizedBox(
                          height: 72,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _voiceState == _VoiceState.thinking
                                    ? 'Thinking...'
                                    : 'Say something...',
                                key: ValueKey(_voiceState),
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.45),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),
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
        ),
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
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text composer (light theme)
// ─────────────────────────────────────────────────────────────────────────────
class _Composer extends StatefulWidget {
  const _Composer({
    required this.onSend,
    required this.onVoiceTap,
    this.disabled = false,
  });
  final ValueChanged<String> onSend;
  final VoidCallback onVoiceTap;
  final bool disabled;

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
              enabled: !widget.disabled,
              style: const TextStyle(color: AppColors.textMain, fontSize: 15),
              maxLines: 5,
              minLines: 1,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.disabled
                    ? 'AI guide requires internet connection'
                    : 'Ask anything...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.add, color: AppColors.textMuted, size: 22),
                const Spacer(),
                const Icon(Icons.mic_none,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onVoiceTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq,
                        color: Colors.white, size: 20),
                  ),
                ),
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
                              decoration: const BoxDecoration(
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
            color: Color(0xFF2A2A2A), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task 11b — Pulse ring painter
// ─────────────────────────────────────────────────────────────────────────────
class _PulseRingPainter extends CustomPainter {
  final List<_PulseRing> rings;
  final double elapsed;
  final double maxRadius;

  const _PulseRingPainter({
    required this.rings,
    required this.elapsed,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final ring in rings) {
      final age = elapsed - ring.birthTime;
      if (age > 0.7 || age < 0) continue;
      final progress = age / 0.7;
      final ringRadius = maxRadius * (1.0 + progress * 0.6);
      final opacity = (1.0 - progress) * 0.4;
      paint.color = const Color(0xFF00AACC).withValues(alpha: opacity);
      canvas.drawCircle(Offset(cx, cy), ringRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.elapsed != elapsed || old.rings.length != rings.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Task 20 — Full SpherePainter (all enhancements)
// ─────────────────────────────────────────────────────────────────────────────
class _SpherePainter extends CustomPainter {
  // Existing
  final double progress;
  final _VoiceState state;
  final bool dense;
  // Task 1
  final double amplitude;
  final double elapsed;
  // Task 2
  final double breathScale;
  final double stateBlend;
  // Task 10
  final double thinkingContraction;
  // Task 12
  final double beatStrength;
  // Task 14/15
  final double entryProgress;
  final bool isExiting;
  // Task 16
  final double idleTiltX;
  // Task 9d
  final int particleCount;

  // Task 9b — static RNG
  static final Random _rng = Random(42);
  // Task 9a — reusable paint
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _SpherePainter({
    required this.progress,
    required this.state,
    this.dense = false,
    this.amplitude = 0.0,
    this.elapsed = 0.0,
    this.breathScale = 1.0,
    this.stateBlend = 0.0,
    this.thinkingContraction = 0.0,
    this.beatStrength = 0.0,
    this.entryProgress = 1.0,
    this.isExiting = false,
    this.idleTiltX = 0.0,
    this.particleCount = 800,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Task 2c — breathing + 2e — thinking contraction
    final contractionFactor = 1.0 - (thinkingContraction * 0.28);
    final baseRadius = (size.width / 2) * breathScale * contractionFactor;

    final count = dense ? 300 : particleCount;

    // Task 6 — blended color palette
    const warmBase = Color(0xFFC05621);
    const warmBright = Color(0xFFFFCB8A);
    const coolBase = Color(0xFF00AACC);
    const coolBright = Color(0xFF88EEFF);
    final base = Color.lerp(warmBase, coolBase, stateBlend)!;
    final bright = Color.lerp(warmBright, coolBright, stateBlend)!;

    // Task 2g — soft inner glow before particles
    final glowStrength = switch (state) {
      _VoiceState.idle => 0.06,
      _VoiceState.listening => 0.10 + amplitude * 0.08,
      _VoiceState.thinking => 0.05,
      _VoiceState.speaking => 0.08 + amplitude * 0.12,
    };
    final glowColor = Color.lerp(warmBase, coolBase, stateBlend)!
        .withValues(alpha: glowStrength);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowColor, Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy), radius: baseRadius * 0.65));
    canvas.drawCircle(Offset(cx, cy), baseRadius * 0.65, glowPaint);

    // Task 2a — variable rotation speed
    final rotSpeed = switch (state) {
      _VoiceState.idle => 0.10,
      _VoiceState.listening => 0.18 + amplitude * 0.12,
      _VoiceState.thinking => 0.08,
      _VoiceState.speaking => 0.13 + amplitude * 0.08,
    };
    final rotY = progress * 2 * pi * rotSpeed;

    // Task 2b — turbulence strength (subtle surface ripple)
    final turbStrength = switch (state) {
      _VoiceState.idle => 0.4,
      _VoiceState.listening => 0.6 + amplitude * 0.8,
      _VoiceState.thinking => 0.3,
      _VoiceState.speaking => 0.5 + amplitude * 0.7,
    };

    // Task 14b — entry: only render a fraction of particles
    final visibleCount =
        entryProgress >= 1.0 ? count : (count * entryProgress).round();

    for (int i = 0; i < visibleCount; i++) {
      // Task 2d — equator bias
      final phi = acos(2 * _rng.nextDouble() - 1);
      final theta = _rng.nextDouble() * 2 * pi;

      // Clean sphere position
      double x0 = baseRadius * sin(phi) * cos(theta);
      double y0 = baseRadius * cos(phi);
      double z0 = baseRadius * sin(phi) * sin(theta);

      // Task 2b — turbulence displacement
      final noiseX = _sineNoise(i, elapsed * 0.8) * turbStrength;
      final noiseY = _sineNoise(i + 1000, elapsed * 0.6) * turbStrength;
      final noiseZ = _sineNoise(i + 2000, elapsed * 1.1) * turbStrength;
      x0 += noiseX;
      y0 += noiseY;
      z0 += noiseZ;

      // Hollow ring — thinking state collapses particles to equatorial shell
      if (state == _VoiceState.thinking && thinkingContraction > 0) {
        final ringBlend = thinkingContraction.clamp(0.0, 1.0);
        // Flatten toward equatorial plane (y → 0)
        y0 *= (1.0 - ringBlend * 0.97);
        // Push xz outward to sphere surface radius
        final xzLen = sqrt(x0 * x0 + z0 * z0);
        if (xzLen > 0.001) {
          final targetScale = baseRadius / xzLen;
          x0 += (x0 * targetScale - x0) * ringBlend * 0.90;
          z0 += (z0 * targetScale - z0) * ringBlend * 0.90;
        }
      }

      // Y-axis rotation
      final xr = cx + x0 * cos(rotY) + z0 * sin(rotY);
      double yr = cy + y0;
      final zr = -x0 * sin(rotY) + z0 * cos(rotY);

      // Task 16a — idle X-axis tilt
      if (state == _VoiceState.idle && idleTiltX > 0) {
        final rotX = sin(idleTiltX * 2 * pi) * 0.14;
        final yRel = yr - cy;
        yr = cy + (yRel * cos(rotX) - zr * sin(rotX));
      }

      // Depth for opacity/size
      final depth = (zr / baseRadius + 1) / 2;
      final amplitudeBoost = amplitude * 0.6;
      final dotSize = dense
          ? (1.2 + 0.3 * depth)
          : (1.2 + 1.8 * depth * 0.9 + amplitudeBoost * depth);

      // Task 2f — brightness threshold
      final beatBrightnessBoost =
          state == _VoiceState.speaking ? beatStrength * 0.20 : 0.0;
      final brightThreshold = 0.85 - beatBrightnessBoost;
      final isBright = _rng.nextDouble() > brightThreshold;

      // Task 2f — flash on loud speaking beats
      final flashBoost =
          (state == _VoiceState.speaking && amplitude > 0.8)
              ? 0.25 * (amplitude - 0.8) / 0.2
              : 0.0;

      // Task 16b — idle twinkle
      double opacity = (0.15 + depth * 0.85).clamp(0.0, 1.0);
      if (state == _VoiceState.idle) {
        final twinklePhase = (i * 0.618) % (2 * pi);
        final twinkle = (sin(elapsed * 1.5 + twinklePhase) + 1) / 2;
        final twinkleBoost =
            twinkle > 0.80 ? (twinkle - 0.80) / 0.20 * 0.35 : 0.0;
        opacity = (opacity + twinkleBoost).clamp(0.0, 1.0);
      }

      final finalOpacity = (opacity + flashBoost).clamp(0.0, 1.0);

      // Compute draw position — apply beat push (Task 12b) or wave (Task 11a)
      double drawX = xr;
      double drawY = yr;

      if (state == _VoiceState.listening) {
        // Task 11a — gentle outward wave
        final waveTime = elapsed * 2.0;
        final particlePhase = (i / count) * 2 * pi;
        final waveValue = sin(waveTime + particlePhase);
        final waveStrength = amplitude > 0.3
            ? (amplitude - 0.3) / 0.7 * 0.8
            : 0.0;
        final dx = drawX - cx;
        final dy = drawY - cy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 0.001 && waveStrength > 0) {
          drawX += (dx / dist) * waveValue * waveStrength;
          drawY += (dy / dist) * waveValue * waveStrength;
        }
      } else if (state == _VoiceState.speaking && beatStrength > 0) {
        // Task 12b — subtle beat push
        final beatPush = beatStrength * 1.2 * depth;
        final dx = drawX - cx;
        final dy = drawY - cy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 0.001) {
          drawX += (dx / dist) * beatPush;
          drawY += (dy / dist) * beatPush;
        }
      } else if (state == _VoiceState.thinking) {
        // Task 10a — very subtle ring shimmer
        drawX += cos(elapsed * 1.0 + i * 0.03) * 0.015 * baseRadius * depth;
        drawY += sin(elapsed * 1.0 + i * 0.03) * 0.015 * baseRadius * depth;
      }

      // Task 15 — scatter on exit
      if (isExiting) {
        final scatterStrength = 35.0 * (1.0 - entryProgress);
        final dx = drawX - cx;
        final dy = drawY - cy;
        final dist = sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
        drawX += (dx / dist) * scatterStrength;
        drawY += (dy / dist) * scatterStrength;
        final exitOpacity = (finalOpacity * entryProgress).clamp(0.0, 1.0);
        _paint.color =
            (isBright ? bright : base).withValues(alpha: exitOpacity);
        canvas.drawCircle(Offset(drawX, drawY), dotSize, _paint);
        continue;
      }

      _paint.color = (isBright ? bright : base).withValues(alpha: finalOpacity);
      final finalDotSize = state == _VoiceState.speaking && beatStrength > 0
          ? dotSize * (1.0 + beatStrength * 0.4)
          : dotSize;
      canvas.drawCircle(Offset(drawX, drawY), finalDotSize, _paint);
    }

    // Task 10c — thinking halo rings
    if (state == _VoiceState.thinking && thinkingContraction > 0.05) {
      _drawThinkingHalos(canvas, Offset(cx, cy), baseRadius);
    }
  }

  void _drawThinkingHalos(
      Canvas canvas, Offset center, double radius) {
    final haloR1 = radius * 0.85 * (1.0 - thinkingContraction * 0.15);
    final haloR2 = radius * 1.05 * (1.0 - thinkingContraction * 0.10);
    final op1 = (thinkingContraction * 0.25).clamp(0.0, 0.25);
    final op2 = (thinkingContraction * 0.15).clamp(0.0, 0.15);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    haloPaint.color = const Color(0xFF00AACC).withValues(alpha: op1);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: haloR1),
        elapsed * 1.2,
        5.76,
        false,
        haloPaint);

    haloPaint.color = const Color(0xFF88EEFF).withValues(alpha: op2);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: haloR2),
        -elapsed * 0.8,
        5.76,
        false,
        haloPaint);
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.progress != progress ||
      old.state != state ||
      old.amplitude != amplitude ||
      old.elapsed != elapsed ||
      old.breathScale != breathScale ||
      old.stateBlend != stateBlend ||
      old.thinkingContraction != thinkingContraction ||
      old.beatStrength != beatStrength ||
      old.entryProgress != entryProgress ||
      old.isExiting != isExiting ||
      old.idleTiltX != idleTiltX;
}
