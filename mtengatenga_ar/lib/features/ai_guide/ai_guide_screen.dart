import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/domain/entities/artifact.model.dart';
import '../../services/gemini_service.dart';
import '../../services/gemini_tts_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_tokens.dart';
import '../map/indoor_navigation_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum _AiMode { text, voice }

enum _VoiceState { idle, listening, thinking, speaking, waiting }

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
      case _VoiceState.waiting:
        return (0.05 + 0.03 * sin(t * 1.4)).clamp(0.0, 1.0);
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

class _ParticleSeed {
  final double theta;
  final double phi;
  final double brightBias;
  final double twinklePhase;
  final double hoverPhase;
  final double hoverStrength;
  final double hoverSpeed;
  final double hoverBand;

  const _ParticleSeed({
    required this.theta,
    required this.phi,
    required this.brightBias,
    required this.twinklePhase,
    required this.hoverPhase,
    required this.hoverStrength,
    required this.hoverSpeed,
    required this.hoverBand,
  });
}

class _VoiceBackdropSpec {
  final Color innerColor;
  final Color midColor;
  final Color outerColor = Colors.black;
  final double radius;
  final Alignment center;

  const _VoiceBackdropSpec({
    required this.innerColor,
    required this.midColor,
    required this.radius,
    this.center = Alignment.bottomCenter,
  });
}

_VoiceBackdropSpec _voiceBackdropFor(_VoiceState state) {
  switch (state) {
    case _VoiceState.idle:
      return const _VoiceBackdropSpec(
        innerColor: Color(0xFF281206),
        midColor: Color(0xFF110702),
        radius: 0.98,
        center: Alignment(0.0, 1.04),
      );
    case _VoiceState.listening:
      return const _VoiceBackdropSpec(
        innerColor: Color(0xFF4D260C),
        midColor: Color(0xFF201004),
        radius: 1.04,
        center: Alignment(0.0, 1.02),
      );
    case _VoiceState.thinking:
      return const _VoiceBackdropSpec(
        innerColor: Color(0xFF063643),
        midColor: Color(0xFF02161E),
        radius: 1.12,
        center: Alignment(0.0, 0.94),
      );
    case _VoiceState.speaking:
      return const _VoiceBackdropSpec(
        innerColor: Color(0xFF0A4352),
        midColor: Color(0xFF03202A),
        radius: 1.16,
        center: Alignment(0.0, 0.90),
      );
    case _VoiceState.waiting:
      return const _VoiceBackdropSpec(
        innerColor: Color(0xFF381A09),
        midColor: Color(0xFF160903),
        radius: 1.01,
        center: Alignment(0.0, 1.00),
      );
  }
}

List<_ParticleSeed> _buildParticleSeeds(int count, {required int seed}) {
  final rng = Random(seed);
  return List<_ParticleSeed>.generate(count, (_) {
    final theta = rng.nextDouble() * 2 * pi;
    final rawPhi = acos(2 * rng.nextDouble() - 1);
    final equatorPull = (pi / 2 - rawPhi) * 0.12;
    final phi = rawPhi + equatorPull;
    return _ParticleSeed(
      theta: theta,
      phi: phi,
      brightBias: rng.nextDouble(),
      twinklePhase: rng.nextDouble() * 2 * pi,
      hoverPhase: rng.nextDouble() * 2 * pi,
      hoverStrength: 1.00 + rng.nextDouble() * 0.90,
      hoverSpeed: 0.45 + rng.nextDouble() * 0.85,
      hoverBand: rng.nextDouble() * 2 * pi,
    );
  });
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
  final _geminiTtsService = GeminiTtsService();
  final _supabaseService = SupabaseService();
  late final FlutterTts _tts;
  late final AudioPlayer _speechPlayer;
  StreamSubscription<PlayerState>? _speechPlayerSub;
  String? _speechTempPath;

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
  bool _isExiting = false;

  // ── Word streaming (Task 4) ────────────────────────────────────────────────
  List<String> _words = [];
  int _revealedWordCount = 0;
  Timer? _wordTimer;
  VoidCallback? _onWordStreamComplete;
  final ScrollController _responseScrollCtrl = ScrollController();

  // ── Amplitude / beat (Tasks 1, 9e, 12a) ───────────────────────────────────
  double _cachedAmplitude = 0.0;
  int _ampFrameCount = 0;
  double _beatStrength = 0.0;
  double _beatDecayStart = 0.0;
  double _lastSpeakingAmp = 0.0;
  bool _ttsCompletionArmed = false;

  // ── Pulse rings (Task 11b) ─────────────────────────────────────────────────
  final List<_PulseRing> _pulseRings = [];
  double _lastAmplitude = 0.0;

  // ── Thinking dots (Task 17) ────────────────────────────────────────────────
  bool _thinkingDotsVisible = false;

  // ── Particle count (Task 9d) ───────────────────────────────────────────────
  late int _particleCount;
  late List<_ParticleSeed> _mainOrbParticles;
  late List<_ParticleSeed> _miniOrbParticles;

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
    _mainOrbParticles = _buildParticleSeeds(_particleCount, seed: 42);
    _miniOrbParticles = _buildParticleSeeds(300, seed: 4242);

    // Existing controllers
    _sphereCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _textFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _textOpacity = CurvedAnimation(parent: _textFadeCtrl, curve: Curves.easeIn);
    _modeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _modeFade = CurvedAnimation(parent: _modeCtrl, curve: Curves.easeInOut);

    // New controllers
    _timeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _stateTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _thinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _orbEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _orbEntryScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
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
      if (mounted) {
        unawaited(_handleTtsCompleted());
      }
    });
    _speechPlayer = AudioPlayer();
    _speechPlayerSub = _speechPlayer.playerStateStream.listen((state) {
      if (!mounted || !_ttsCompletionArmed) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_handleTtsCompleted());
      }
    });

    _checkConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
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
    _speechPlayerSub?.cancel();
    unawaited(_speechPlayer.stop());
    unawaited(_speechPlayer.dispose());
    _tts.stop();
    if (_speechTempPath != null) {
      try {
        File(_speechTempPath!).deleteSync();
      } catch (_) {
        // Ignore temp cleanup failures during dispose.
      }
    }
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
  bool get _showTranscript => _words.isNotEmpty;
  bool get _showMiniOrb =>
      _voiceState == _VoiceState.speaking || _voiceState == _VoiceState.waiting;
  bool get _showCenterOrb => !_showMiniOrb;
  bool get _showControls => !_isExiting;
  double get _coolTransitionBlend => Curves.easeInOutCubicEmphasized.transform(
    _stateTransitionCtrl.value.clamp(0.0, 1.0),
  );
  double get _elapsedSeconds => _timeCtrl.value * 60.0;
  String get _voiceStatusText => switch (_voiceState) {
    _VoiceState.listening => 'Listening...',
    _VoiceState.thinking => 'Thinking...',
    _VoiceState.speaking => '',
    _VoiceState.waiting || _VoiceState.idle => 'Say something...',
  };

  Future<void> _handleTtsCompleted() async {
    if (!_ttsCompletionArmed ||
        _mode != _AiMode.voice ||
        _voiceState != _VoiceState.speaking) {
      return;
    }
    await _settleToWaitingState();
  }

  Future<File> _persistSpeechAudio(Uint8List wavBytes) async {
    if (_speechTempPath != null) {
      try {
        await File(_speechTempPath!).delete();
      } catch (_) {
        // Ignore temp cleanup failures and replace the file path below.
      }
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}'
      'mtengatenga_voice_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(wavBytes, flush: true);
    _speechTempPath = file.path;
    return file;
  }

  Future<void> _playGeminiSpeech(String text) async {
    final wavBytes = await _geminiTtsService.synthesizeSpeech(text);
    if (!_ttsCompletionArmed ||
        !mounted ||
        _mode != _AiMode.voice ||
        _voiceState != _VoiceState.speaking) {
      return;
    }

    final audioFile = await _persistSpeechAudio(wavBytes);
    if (!_ttsCompletionArmed ||
        !mounted ||
        _mode != _AiMode.voice ||
        _voiceState != _VoiceState.speaking) {
      return;
    }

    await _speechPlayer.setFilePath(audioFile.path);
    await _speechPlayer.play();
  }

  Future<void> _stopTtsPlayback() async {
    _ttsCompletionArmed = false;
    try {
      await _speechPlayer.stop();
    } catch (_) {
      // Ignore audio player stop failures and continue resetting the UI.
    }
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore plugin stop failures and continue resetting the UI.
    }
  }

  void _resetVoiceReactivity() {
    _pulseRings.clear();
    _lastAmplitude = 0.0;
    _beatStrength = 0.0;
    _beatDecayStart = 0.0;
    _lastSpeakingAmp = 0.0;
  }

  Future<void> _clearVoiceTranscript({bool animate = true}) async {
    _cancelWordStream();
    if (_showTranscript && animate && _textFadeCtrl.value > 0) {
      await _textFadeCtrl.reverse();
    } else {
      _textFadeCtrl.reset();
    }

    if (!mounted) return;
    setState(() {
      _words = [];
      _revealedWordCount = 0;
    });
    if (_responseScrollCtrl.hasClients) {
      _responseScrollCtrl.jumpTo(0);
    }
  }

  Future<void> _resetVoiceOverlayState() async {
    await _stopTtsPlayback();
    _cancelWordStream();
    _resetVoiceReactivity();
    _pulseCtrl
      ..stop()
      ..reset();
    _textFadeCtrl.reset();
    _stateTransitionCtrl.value = 0.0;
    _thinkCtrl.value = 0.0;

    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.idle;
      _words = [];
      _revealedWordCount = 0;
      _thinkingDotsVisible = false;
      _isExiting = false;
    });
  }

  void _onTimeTick() {
    if (!mounted) return;
    _ampFrameCount++;
    if (_ampFrameCount.isEven) {
      _cachedAmplitude = _AmplitudeEngine.getValue(
        _elapsedSeconds,
        _voiceState,
      );
      _updateBeatDetection(_elapsedSeconds);
      _checkPulseEmit(_elapsedSeconds);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 12a — Beat detection
  // ─────────────────────────────────────────────────────────────────────────
  void _updateBeatDetection(double elapsed) {
    if (_voiceState != _VoiceState.speaking) {
      _beatStrength = 0.0;
      _lastSpeakingAmp = 0.0;
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
    setState(() {
      _voiceState = newState;
      if (newState != _VoiceState.thinking) {
        _thinkingDotsVisible = false;
      }
    });

    if (newState == _VoiceState.speaking) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl
        ..stop()
        ..reset();
    }

    switch (newState) {
      case _VoiceState.idle:
        _stateTransitionCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
        _thinkCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
        break;
      case _VoiceState.listening:
        _stateTransitionCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
        );
        _thinkCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        break;
      case _VoiceState.thinking:
        _stateTransitionCtrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 920),
          curve: Curves.easeInOutCubicEmphasized,
        );
        _thinkCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _voiceState == _VoiceState.thinking) {
            setState(() => _thinkingDotsVisible = true);
          }
        });
        break;
      case _VoiceState.speaking:
        _stateTransitionCtrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
        _thinkCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
        );
        break;
      case _VoiceState.waiting:
        _stateTransitionCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 820),
          curve: Curves.easeInOutCubic,
        );
        _thinkCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
        );
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 3b — Sequenced orb-shrink → text-stream
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startListeningTurn() async {
    await _stopTtsPlayback();
    _resetVoiceReactivity();
    if (_showTranscript) {
      await _clearVoiceTranscript();
    }
    if (!mounted) return;
    _onStateChanged(_VoiceState.listening);
  }

  Future<void> _enterSpeakingState(String text, {bool speakText = true}) async {
    _onStateChanged(_VoiceState.speaking);
    await Future.delayed(const Duration(milliseconds: 560));
    if (!mounted || _voiceState != _VoiceState.speaking) return;

    _textFadeCtrl.forward(from: 0.0);
    _streamWords(
      text,
      onComplete: speakText
          ? null
          : () {
              if (mounted && _voiceState == _VoiceState.speaking) {
                unawaited(_settleToWaitingState());
              }
            },
    );

    if (!speakText) return;

    _ttsCompletionArmed = true;
    try {
      await _playGeminiSpeech(text);
    } catch (e, st) {
      debugPrint(
        'Gemini voice playback failed, falling back to device TTS: $e',
      );
      debugPrintStack(stackTrace: st);
      if (!_ttsCompletionArmed ||
          !mounted ||
          _mode != _AiMode.voice ||
          _voiceState != _VoiceState.speaking) {
        return;
      }
      try {
        await _tts.speak(text);
      } catch (_) {
        await _settleToWaitingState();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 4 — Word streaming
  // ─────────────────────────────────────────────────────────────────────────
  void _streamWords(String fullText, {VoidCallback? onComplete}) {
    final normalizedText = fullText.trim();
    _cancelWordStream();

    if (normalizedText.isEmpty) {
      onComplete?.call();
      return;
    }

    _onWordStreamComplete = onComplete;
    setState(() {
      _words = normalizedText.split(RegExp(r'\s+'));
      _revealedWordCount = 0;
    });
    _scheduleNextWord();
  }

  void _scheduleNextWord() {
    if (_revealedWordCount >= _words.length) {
      final onComplete = _onWordStreamComplete;
      _onWordStreamComplete = null;
      onComplete?.call();
      return;
    }

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
    _onWordStreamComplete = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reset to idle (Tasks 4e, 5)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _settleToWaitingState() async {
    _ttsCompletionArmed = false;
    _cancelWordStream();
    if (!mounted || _mode != _AiMode.voice) return;

    setState(() {
      _revealedWordCount = _words.length;
    });
    _textFadeCtrl.forward();
    _onStateChanged(_VoiceState.waiting);
  }

  Future<void> _setIdleState({bool clearTranscript = true}) async {
    await _stopTtsPlayback();
    _resetVoiceReactivity();
    if (clearTranscript) {
      await _clearVoiceTranscript(animate: false);
    } else {
      _cancelWordStream();
    }
    if (!mounted) return;
    _onStateChanged(_VoiceState.idle);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 14 — Voice mode entry
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _enterVoice() async {
    HapticFeedback.mediumImpact();
    await _resetVoiceOverlayState();
    if (!mounted) return;
    setState(() => _mode = _AiMode.voice);
    await _modeCtrl.forward();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _orbEntryCtrl.forward(from: 0.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task 15 — Voice mode exit
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _exitVoice() async {
    await _stopTtsPlayback();
    _cancelWordStream();
    setState(() => _isExiting = true);
    await _orbEntryCtrl.reverse();
    if (!mounted) return;
    await _modeCtrl.reverse();
    if (!mounted) return;
    await _resetVoiceOverlayState();
    if (!mounted) return;
    setState(() => _mode = _AiMode.text);
    _orbEntryCtrl.reset();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Orb tap handler
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleOrbTap() async {
    HapticFeedback.mediumImpact();
    switch (_voiceState) {
      case _VoiceState.idle:
      case _VoiceState.waiting:
        await _startListeningTurn();
        if (!mounted) return;
        unawaited(_runDemoFlow());
        break;
      case _VoiceState.listening:
      case _VoiceState.thinking:
        await _setIdleState(clearTranscript: false);
        break;
      case _VoiceState.speaking:
        await _stopTtsPlayback();
        await _settleToWaitingState();
        break;
    }
  }

  Future<void> _runDemoFlow() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _voiceState != _VoiceState.listening) return;
    _onStateChanged(_VoiceState.thinking);

    final prompt = widget.artifact != null
        ? 'Give me a brief, engaging introduction to this artifact.'
        : 'Welcome me to Mtengatenga Museum and give me a brief overview of what I can explore here.';

    try {
      if (_isOffline) {
        throw const SocketException('Offline');
      }

      final response = await _geminiService.voiceQuery(widget.artifact, prompt);
      if (!mounted || _voiceState != _VoiceState.thinking) return;

      final safeResponse = response.trim().isEmpty
          ? 'I have a quiet moment right now. Try asking again and I will jump back in.'
          : response.trim();
      await _enterSpeakingState(safeResponse);
    } catch (_) {
      if (!mounted || _voiceState != _VoiceState.thinking) return;
      final fallback = _isOffline
          ? 'Voice guide needs an internet connection before I can answer out loud.'
          : 'I hit a snag preparing that response. Please try again in a moment.';
      await _enterSpeakingState(fallback, speakText: false);
    }
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
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${tour['duration_minutes']} min  •  ${tour['difficulty']}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
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
        Expanded(child: _messages.isEmpty ? _buildEmptyState() : _buildChat()),
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
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 12,
              ),
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
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textMuted,
                  size: 16,
                ),
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
                child: Icon(
                  Icons.route,
                  color: _tourMode ? AppColors.primary : AppColors.textMuted,
                  size: 17,
                ),
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
                child: const Icon(
                  Icons.history,
                  color: AppColors.textMuted,
                  size: 18,
                ),
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
          const Icon(Icons.route, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  stopLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IndoorNavigationScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              style: TextStyle(fontSize: 30, letterSpacing: -0.5, height: 1.2),
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
            children: _buildSuggestions()
                .map(
                  (s) =>
                      _SuggestionChip(label: s, onTap: () => _sendMessage(s)),
                )
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              color: AppColors.textMain,
              fontSize: 15,
              height: 1.45,
            ),
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
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 12,
                ),
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
              color: AppColors.textMuted,
              fontSize: 16,
              height: 1.6,
            ),
          ),
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
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.surfaceBorder,
                      height: 1,
                    ),
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          m.isUser ? Icons.person_outline : Icons.auto_awesome,
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
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
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
          if (_showTranscript) _voiceResponseText(),
          _voiceTopBar(),
          _voiceIndicators(),
          _voiceBottomBar(),
        ],
      ),
    );
  }

  // Task 8 — Enhanced background gradient
  Widget _voiceBg() {
    final spec = _voiceBackdropFor(_voiceState);
    final duration = switch (_voiceState) {
      _VoiceState.thinking => const Duration(milliseconds: 920),
      _VoiceState.speaking => const Duration(milliseconds: 640),
      _VoiceState.waiting => const Duration(milliseconds: 820),
      _VoiceState.listening => const Duration(milliseconds: 520),
      _VoiceState.idle => const Duration(milliseconds: 700),
    };
    final curve = switch (_voiceState) {
      _VoiceState.thinking => Curves.easeInOutCubicEmphasized,
      _VoiceState.speaking => Curves.easeOutCubic,
      _ => Curves.easeInOutCubic,
    };

    return Positioned.fill(
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: spec.center,
            radius: spec.radius,
            colors: [spec.innerColor, spec.midColor, spec.outerColor],
            stops: const [0.0, 0.46, 1.0],
          ),
        ),
      ),
    );
  }

  // Tasks 2, 9c, 14, 15 — Single animated orb layer
  Widget _voiceSphereArea() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final orbSize = _showMiniOrb ? 76.0 : 228.0;
    final layerSize = _showMiniOrb ? 96.0 : orbSize * 2.2;
    final orbPadding = EdgeInsets.only(
      bottom: _showMiniOrb ? bottomInset + 24 : 0,
    );

    return AnimatedAlign(
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeInOutCubic,
      alignment: _showMiniOrb ? Alignment.bottomCenter : Alignment.center,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeInOutCubic,
        padding: orbPadding,
        child: GestureDetector(
          onTap: _showControls ? () => unawaited(_handleOrbTap()) : null,
          child: SizedBox(
            width: layerSize,
            height: layerSize,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _sphereCtrl,
                  _breathCtrl,
                  _timeCtrl,
                  _stateTransitionCtrl,
                  _thinkCtrl,
                  _orbEntryCtrl,
                ]),
                builder: (_, __) {
                  final particles = _showMiniOrb
                      ? _miniOrbParticles
                      : _mainOrbParticles;
                  final breathScale = switch (_voiceState) {
                    _VoiceState.idle => 0.98 + 0.010 * _breathCtrl.value,
                    _VoiceState.listening => 0.98 + 0.012 * _breathCtrl.value,
                    _VoiceState.thinking => 0.98 + 0.010 * _breathCtrl.value,
                    _VoiceState.speaking => 0.94 + 0.012 * _breathCtrl.value,
                    _VoiceState.waiting => 0.98 + 0.010 * _breathCtrl.value,
                  };

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (_voiceState == _VoiceState.listening &&
                          _showCenterOrb)
                        CustomPaint(
                          painter: _PulseRingPainter(
                            rings: List<_PulseRing>.from(_pulseRings),
                            elapsed: _elapsedSeconds,
                            maxRadius: orbSize / 2,
                            color: const Color(0xFFD2874B),
                          ),
                          size: Size(layerSize, layerSize),
                        ),
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
                                  particles: particles,
                                  dense: _showMiniOrb,
                                  amplitude: _cachedAmplitude,
                                  elapsed: _elapsedSeconds,
                                  breathScale: breathScale,
                                  stateBlend: _coolTransitionBlend,
                                  thinkingContraction: _thinkCtrl.value,
                                  beatStrength: _beatStrength,
                                  entryProgress: _orbEntryCtrl.value,
                                  isExiting: _isExiting,
                                  idleTiltX: 0.0,
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
      ),
    );
  }

  // Task 18 — Scrollable response text with fade mask
  Widget _voiceResponseText() {
    return Positioned(
      top: 84,
      left: 28,
      right: 28,
      bottom: 208,
      child: FadeTransition(
        opacity: _textOpacity,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.82, 1.0],
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
      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            fontSize: isLastActive ? 32 : 31,
            fontWeight: isLastActive ? FontWeight.w600 : FontWeight.w300,
            color: isLastActive ? Colors.white : const Color(0xFFA0A0A5),
            height: 1.24,
            letterSpacing: -0.35,
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 80),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(
        key: ValueKey(_revealedWordCount),
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(children: spans),
        ),
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
          opacity: switch (_voiceState) {
            _VoiceState.speaking => 0.16,
            _VoiceState.waiting => 0.36,
            _VoiceState.thinking => 0.58,
            _ => 0.78,
          },
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
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
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
              _VoiceState.thinking when _thinkingDotsVisible => KeyedSubtree(
                key: const ValueKey('dots'),
                child: _buildThinkingDots(),
              ),
              _ => const SizedBox(height: 28, key: ValueKey('empty')),
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _voiceStatusText.isEmpty
                ? const SizedBox(height: 20, key: ValueKey('status-empty'))
                : Text(
                    _voiceStatusText,
                    key: ValueKey(_voiceStatusText),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withValues(alpha: 0.52),
                      letterSpacing: 0.25,
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
      color: const Color(0xFFD2874B).withValues(alpha: 0.85),
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
    if (!_showControls) return const SizedBox.shrink();

    final buttonOpacity = switch (_voiceState) {
      _VoiceState.speaking => 0.18,
      _VoiceState.waiting => 0.42,
      _ => 1.0,
    };

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Row(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: buttonOpacity,
                child: _OrbBtn(icon: Icons.close, onTap: _exitVoice),
              ),
              const Spacer(),
              const SizedBox(width: 76, height: 76),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: buttonOpacity,
                child: _OrbBtn(
                  icon: Icons.mic_none_rounded,
                  onTap: () => unawaited(_handleOrbTap()),
                ),
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
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                ),
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
                const Icon(
                  Icons.mic_none,
                  color: AppColors.textMuted,
                  size: 22,
                ),
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
                    child: const Icon(
                      Icons.graphic_eq,
                      color: Colors.white,
                      size: 20,
                    ),
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
                              child: const Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 20,
                              ),
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
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
  final Color color;

  const _PulseRingPainter({
    required this.rings,
    required this.elapsed,
    required this.maxRadius,
    required this.color,
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
      paint.color = color.withValues(alpha: opacity);
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
  final double progress;
  final _VoiceState state;
  final List<_ParticleSeed> particles;
  final bool dense;
  final double amplitude;
  final double elapsed;
  final double breathScale;
  final double stateBlend;
  final double thinkingContraction;
  final double beatStrength;
  final double entryProgress;
  final bool isExiting;
  final double idleTiltX;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _SpherePainter({
    required this.progress,
    required this.state,
    required this.particles,
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = (size.width / 2) * breathScale;
    const warmBase = Color(0xFFC05621);
    const warmBright = Color(0xFFFFCB8A);
    const coolBase = Color(0xFF00AACC);
    const coolBright = Color(0xFF88EEFF);
    final base = Color.lerp(warmBase, coolBase, stateBlend)!;
    final bright = Color.lerp(warmBright, coolBright, stateBlend)!;

    final glowStrength = switch (state) {
      _VoiceState.idle => 0.06,
      _VoiceState.listening => 0.08 + amplitude * 0.05,
      _VoiceState.thinking => 0.05,
      _VoiceState.speaking => 0.08 + amplitude * 0.12,
      _VoiceState.waiting => 0.07,
    };
    final glowColor = Color.lerp(
      warmBase,
      coolBase,
      stateBlend,
    )!.withValues(alpha: glowStrength);
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [glowColor, Colors.transparent])
          .createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: baseRadius * 0.65),
          );
    canvas.drawCircle(Offset(cx, cy), baseRadius * 0.65, glowPaint);

    final rotSpeed = switch (state) {
      _VoiceState.idle => 0.11,
      _VoiceState.listening => 0.12,
      _VoiceState.thinking => 0.08,
      _VoiceState.speaking => 0.11,
      _VoiceState.waiting => 0.10,
    };
    final rotY = elapsed * rotSpeed;

    final turbStrength = switch (state) {
      _VoiceState.idle => 0.35,
      _VoiceState.listening => 0.45 + amplitude * 0.65,
      _VoiceState.thinking => 0.30,
      _VoiceState.speaking => 0.50 + amplitude * 0.70,
      _VoiceState.waiting => 0.28,
    };

    final visibleCount = entryProgress >= 1.0
        ? particles.length
        : (particles.length * entryProgress).round();
    final renderedParticles =
        <({double z, double x, double y, double size, Color color})>[];

    for (int i = 0; i < visibleCount; i++) {
      final particle = particles[i];
      final phi = particle.phi;
      final theta = particle.theta;
      double x0 = baseRadius * sin(phi) * cos(theta);
      double y0 = baseRadius * cos(phi);
      double z0 = baseRadius * sin(phi) * sin(theta);

      final radiusOffset = _sineNoise(i, elapsed * 0.75) * turbStrength;
      final radiusScale = ((baseRadius + radiusOffset) / max(baseRadius, 1))
          .clamp(0.96, 1.04);
      x0 *= radiusScale;
      y0 *= radiusScale;
      z0 *= radiusScale;

      final normalLength = sqrt(
        x0 * x0 + y0 * y0 + z0 * z0,
      ).clamp(0.001, double.infinity);
      final nx = x0 / normalLength;
      final ny = y0 / normalLength;
      final nz = z0 / normalLength;
      final swarmWave =
          (sin(elapsed * 0.95 + particle.hoverBand + phi * 1.2 - theta * 0.4) +
              1) /
          2;
      final floatPulse = pow(
        max(0.0, sin(elapsed * particle.hoverSpeed + particle.hoverPhase)),
        1.10,
      ).toDouble();
      final stateLift = switch (state) {
        _VoiceState.idle => baseRadius * (dense ? 0.062 : 0.100),
        _VoiceState.listening =>
          baseRadius * ((dense ? 0.065 : 0.104) + amplitude * 0.022),
        _VoiceState.thinking => baseRadius * (dense ? 0.020 : 0.032),
        _VoiceState.speaking =>
          baseRadius * ((dense ? 0.058 : 0.092) + beatStrength * 0.020),
        _VoiceState.waiting => baseRadius * (dense ? 0.070 : 0.115),
      };
      final liftDistance =
          stateLift *
          particle.hoverStrength *
          floatPulse *
          (0.35 + 0.65 * swarmWave);
      final liftNormalized = stateLift <= 0
          ? 0.0
          : (liftDistance / stateLift).clamp(0.0, 1.0);
      x0 += nx * liftDistance;
      y0 += ny * liftDistance;
      z0 += nz * liftDistance;

      // Y-axis rotation
      double rotatedX = x0 * cos(rotY) + z0 * sin(rotY);
      double rotatedY = y0;
      double rotatedZ = -x0 * sin(rotY) + z0 * cos(rotY);

      if (state == _VoiceState.idle && idleTiltX > 0) {
        final rotX = sin(idleTiltX * 2 * pi) * 0.14;
        final tiltedY = rotatedY * cos(rotX) - rotatedZ * sin(rotX);
        final tiltedZ = rotatedY * sin(rotX) + rotatedZ * cos(rotX);
        rotatedY = tiltedY;
        rotatedZ = tiltedZ;
      }

      final perspectiveStrength = dense ? 0.22 : 0.36;
      final perspectiveScale =
          (1.0 + (rotatedZ / max(baseRadius, 1)) * perspectiveStrength).clamp(
            0.74,
            1.48,
          );
      final depth = ((rotatedZ / max(baseRadius, 1)) + 1) / 2;
      double drawX = cx + rotatedX * perspectiveScale;
      double drawY = cy + rotatedY * perspectiveScale;

      final amplitudeBoost = amplitude * 0.45;
      double dotSize = dense
          ? (1.0 + 0.45 * depth + amplitudeBoost * 0.15)
          : (1.15 + 1.65 * depth + amplitudeBoost * depth);
      dotSize += liftNormalized * (dense ? 0.42 : 0.90) * (0.60 + depth);

      final beatBrightnessBoost = state == _VoiceState.speaking
          ? beatStrength * 0.20
          : 0.0;
      final brightThreshold = switch (state) {
        _VoiceState.speaking => 0.72 - beatBrightnessBoost,
        _VoiceState.thinking => 0.80,
        _ => 0.86,
      }.clamp(0.55, 0.95);
      final isBright = particle.brightBias > brightThreshold;

      final flashBoost = (state == _VoiceState.speaking && amplitude > 0.8)
          ? 0.25 * (amplitude - 0.8) / 0.2
          : 0.0;

      double opacity = (0.15 + depth * 0.85).clamp(0.0, 1.0);
      if (state == _VoiceState.idle || state == _VoiceState.waiting) {
        final twinkle = (sin(elapsed * 1.5 + particle.twinklePhase) + 1) / 2;
        final twinkleBoost = twinkle > 0.80
            ? (twinkle - 0.80) / 0.20 * 0.35
            : 0.0;
        opacity = (opacity + twinkleBoost).clamp(0.0, 1.0);
      }
      opacity = (opacity + liftNormalized * 0.34 * depth).clamp(0.0, 1.0);

      final finalOpacity = (opacity + flashBoost).clamp(0.0, 1.0);

      final dxToCenter = drawX - cx;
      final dyToCenter = drawY - cy;
      final distToCenter = sqrt(
        dxToCenter * dxToCenter + dyToCenter * dyToCenter,
      );
      final maxSilhouetteRadius = baseRadius * (dense ? 1.03 : 1.05);
      if (!isExiting && distToCenter > maxSilhouetteRadius) {
        final clampScale = maxSilhouetteRadius / distToCenter;
        drawX = cx + dxToCenter * clampScale;
        drawY = cy + dyToCenter * clampScale;
      }

      if (isExiting) {
        final scatterStrength = 35.0 * (1.0 - entryProgress);
        final dx = drawX - cx;
        final dy = drawY - cy;
        final dist = sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
        drawX += (dx / dist) * scatterStrength;
        drawY += (dy / dist) * scatterStrength;
        final exitOpacity = (finalOpacity * entryProgress).clamp(0.0, 1.0);
        _paint.color = (isBright ? bright : base).withValues(
          alpha: exitOpacity,
        );
        canvas.drawCircle(Offset(drawX, drawY), dotSize, _paint);
        continue;
      }

      final finalDotSize = state == _VoiceState.speaking && beatStrength > 0
          ? dotSize * (1.0 + beatStrength * 0.4)
          : dotSize;
      renderedParticles.add((
        z: rotatedZ + liftDistance,
        x: drawX,
        y: drawY,
        size: finalDotSize,
        color: (isBright ? bright : base).withValues(alpha: finalOpacity),
      ));
    }

    renderedParticles.sort((a, b) => a.z.compareTo(b.z));
    for (final particle in renderedParticles) {
      _paint.color = particle.color;
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, _paint);
    }

    if (state == _VoiceState.thinking && thinkingContraction > 0.05) {
      _drawThinkingHalos(canvas, Offset(cx, cy), baseRadius);
    }
  }

  void _drawThinkingHalos(Canvas canvas, Offset center, double radius) {
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
      haloPaint,
    );

    haloPaint.color = const Color(0xFF88EEFF).withValues(alpha: op2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: haloR2),
      -elapsed * 0.8,
      5.76,
      false,
      haloPaint,
    );
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.progress != progress ||
      old.state != state ||
      old.particles != particles ||
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
