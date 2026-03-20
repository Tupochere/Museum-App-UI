  
Here is a summary of what the full plan covers across all 24 tasks:

**Foundation (Tasks 1, 20, 21):** `_AmplitudeEngine` fake audio signal, full `SpherePainter` parameter signature, all 9 `AnimationController` declarations with init and dispose.

**Sphere Enhancements (Task 2):** Variable rotation speed, pseudo-noise turbulence displacement, organic breathing scale, equator density bias, thinking radius contraction, amplitude-driven particle size/brightness, and soft inner glow.

**State Transitions (Task 3):** Spring-like `_stateTransitionCtrl`, sequenced orb-shrinks-before-text, refined teal-rises-from-bottom background gradient.

**Text Streaming (Task 4):** Word-by-word reveal with natural speech timing delays, bold+bright last word highlight, micro fade per word, auto-scroll, and clean teardown.

**Per-State Visual Personalities (Tasks 10–12, 16):** Thinking spiral contraction + rotating halo rings, listening outward wave bursts + pulse ring emitter, speaking beat detection + surface undulation + brightness flash, idle X-axis tilt + ambient particle twinkle.

**UI Polish (Tasks 5–8, 13, 17–19):** Button fade during speaking, mini orb smooth color blend, status label crossfade, background gradient stops, 5-bar mic waveform, 3-dot thinking indicator, scrollable text with fade mask, settings icon frosted pill.

**Entry/Exit (Tasks 14–15):** Orb materializes with particle coalesce on enter, orb scatters/dissolves on exit.

**Developer Guides (Tasks 22–24):** Exact implementation phase order, computed values reference sheet, and 5 clearly marked STT/TTS plug-in points for when real audio is wired.

Here is the complete implementation plan MD file. Copy everything between the triple backticks and save it as `VOICE_MODE_ENHANCEMENT_PLAN.md`:

text

``# Voice Mode Enhancement Plan ## Mtengatenga AR Museum — AI Guide Voice UX ### Target: Match Perplexity-level animation quality using pure Flutter --- ## Reading Guide for Claude This document is a precise, ordered implementation plan. Each section is a self-contained enhancement task. Work through them **in the order listed** — earlier tasks lay the foundation later tasks depend on. Every code suggestion targets `lib/features/ai_guide/ai_guide_screen.dart` unless stated otherwise. Do NOT restructure the existing state machine or controller setup — enhance on top of what exists. --- ## Current Architecture Summary (Do Not Change) ```dart enum AiMode { text, voice } enum VoiceState { idle, listening, thinking, speaking } // Controllers already in place: // sphereCtrl  — 4s repeat — drives sphere rotation (progress 0.0→1.0) // pulseCtrl   — 1.2s repeat reverse — scale 0.95→1.05 during speaking // textFadeCtrl — 450ms — fades AI response text in // modeCtrl   — 350ms — fades voice overlay over text mode // SpherePainter draws 800 particles (300 dense) using spherical coordinates // Fixed seed Random(42) — intentional, do not change // Warm palette: idle+speaking | Cool palette: listening+thinking``

---

## TASK 1 — Fake Audio Amplitude Engine

## Priority: HIGH — Everything else plugs into this

Build a `_AmplitudeEngine` that produces a continuous fake amplitude signal  
during the demo flow. When real STT/TTS is wired later, swap the source only.

**Add this class above the State widget:**

dart

`class _AmplitudeEngine {   // Returns a value 0.0–1.0 representing "loudness" at any given moment.  // Composed of 3 sine waves at different frequencies to feel organic,  // not mechanical. Mimics natural speech rhythm.  static double getValue(double timeSeconds, VoiceState state) {    if (state == VoiceState.idle) return 0.0;    if (state == VoiceState.thinking) {      // Slow, low-amplitude pulse — like processing hum      return 0.08 + 0.06 * sin(timeSeconds * 1.2);    }    if (state == VoiceState.listening) {      // Irregular, reactive — simulates mic picking up user voice      return (0.3 + 0.4 * sin(timeSeconds * 3.7) +              0.2 * sin(timeSeconds * 7.1) +              0.1 * sin(timeSeconds * 13.3))          .clamp(0.0, 1.0);    }    if (state == VoiceState.speaking) {      // Speech rhythm: strong beats with variation      // Stressed syllable pattern roughly every 0.4s      final beat = sin(timeSeconds * pi / 0.4);      final base = 0.45 + 0.3 * beat;      final texture = 0.15 * sin(timeSeconds * 9.2);      final breathe = 0.1 * sin(timeSeconds * 0.7);      return (base + texture + breathe).clamp(0.0, 1.0);    }    return 0.0;  } }`

**Wire it into the build:**

- Add a `Ticker` (via `SingleTickerProviderStateMixin` already present) or  
    use a simple `AnimationController` with infinite duration to track elapsed  
    seconds: `_timeCtrl` — 60s repeat, gives `_timeCtrl.value * 60` as seconds.
    
- Pass `amplitude = _AmplitudeEngine.getValue(elapsed, _voiceState)` down to  
    `SpherePainter` and any widget that needs it.
    

**Add to controller declarations:**

dart

`late AnimationController _timeCtrl; // 60s repeat — wall-clock driver double get _elapsed => _timeCtrl.value * 60.0; // seconds 0–60 looping double get _amplitude => _AmplitudeEngine.getValue(_elapsed, _voiceState);`

**Init:**

dart

`_timeCtrl = AnimationController(   vsync: this,  duration: const Duration(seconds: 60), )..repeat();`

---

## TASK 2 — SpherePainter: Organic Breathing + Variable Rotation

## File: SpherePainter class

## Depends on: Task 1 (_amplitude value passed in)

**Add these parameters to SpherePainter:**

dart

`final double amplitude;      // 0.0–1.0 from _AmplitudeEngine final double elapsed;        // seconds, for time-based turbulence final double breathScale;    // 0.92–1.08 organic size oscillation`

## 2a — Variable Rotation Speed

Replace the fixed `rotY = progress * 2 * pi * 0.35` with state-aware speed:

dart

`// Rotation multiplier per state: // idle      → 0.25 (slow, meditative) // listening → 0.55 + amplitude*0.4 (reacts to input) // thinking  → 0.18 (slow inward focus) // speaking  → 0.35 + amplitude*0.25 (speech rhythm) final double rotSpeed = switch (state) {   VoiceState.idle      => 0.25,  VoiceState.listening => 0.55 + amplitude * 0.4,  VoiceState.thinking  => 0.18,  VoiceState.speaking  => 0.35 + amplitude * 0.25, }; final rotY = progress * 2 * pi * rotSpeed;`

## 2b — Turbulence / Noise Displacement on Particle Positions

After computing `x0, y0, z0` (the clean sphere position), apply displacement.  
Use a deterministic pseudo-noise from sin/cos combinations — no external  
package needed:

dart

`// Pseudo-noise: each particle gets unique displacement based on its index // and elapsed time. This makes the surface feel alive without Perlin noise. double _noise(int seed, double t) {   final s = seed * 127 + 1;  return sin(s * 0.317 + t * 1.7) * cos(s * 0.573 + t * 0.9); } // Inside paint loop, after computing x0,y0,z0: final turbStrength = switch (state) {   VoiceState.idle      => 4.0,  VoiceState.listening => 8.0 + amplitude * 18.0,  VoiceState.thinking  => 3.0,  VoiceState.speaking  => 6.0 + amplitude * 14.0, }; final noiseX = _noise(i, elapsed * 0.8) * turbStrength; final noiseY = _noise(i + 1000, elapsed * 0.6) * turbStrength; final noiseZ = _noise(i + 2000, elapsed * 1.1) * turbStrength; // Apply before rotation: final x0d = x0 + noiseX; final y0d = y0 + noiseY; final z0d = z0 + noiseZ; // Then use x0d,y0d,z0d in the rotation math instead of x0,y0,z0`

## 2c — Organic Breathing Scale

The `breathScale` parameter (computed outside the painter) controls the  
overall radius. Wire it via a dedicated AnimationController:

dart

`// Outside painter, in State: late AnimationController _breathCtrl; // Init: _breathCtrl = AnimationController(   vsync: this,  duration: const Duration(milliseconds: 3200), )..repeat(reverse: true); // Compute breathScale in build: final breathScale = switch (_voiceState) {   VoiceState.idle      => 0.97 + 0.03 * _breathCtrl.value,    // gentle  VoiceState.listening => 0.93 + 0.10 * _breathCtrl.value,    // more active  VoiceState.thinking  => 0.95 + 0.02 * _breathCtrl.value,    // contracted  VoiceState.speaking  => 0.94 + 0.08 * _breathCtrl.value + amplitude * 0.06, };`

Inside `SpherePainter.paint`, multiply `radius` by `breathScale`:

dart

`final effectiveRadius = (size.width / 2) * breathScale;`

## 2d — Equator Density Boost

Perplexity's sphere has more particles clustered near the equator. Achieve  
this by biasing the `phi` distribution without breaking the fixed seed:

dart

`// Replace: final phi = acos(2 * rng.nextDouble() - 1); // With a bias toward equator (phi ≈ pi/2): final rawPhi = acos(2 * rng.nextDouble() - 1); // Pull 40% of particles toward equator final equatorBias = (pi / 2 - rawPhi) * 0.4; final phi = rawPhi + equatorBias;`

## 2e — Thinking State: Radius Contraction

dart

`// Thinking state contracts particles inward final radiusMultiplier = state == VoiceState.thinking     ? 0.72 + 0.08 * sin(elapsed * 1.4)  // slow inward pulse    : 1.0; final effectiveRadius = (size.width / 2) * breathScale * radiusMultiplier;`

## 2f — Particle Size and Brightness Tied to Amplitude

dart

`// Current: final dotSize = dense ? ... : (1.2 + 1.8 * depth * 0.9) // Enhanced: final amplitudeBoost = amplitude * 0.6; final dotSize = dense     ? (1.2 + 0.3 * depth)    : (1.2 + 1.8 * depth * 0.9 + amplitudeBoost * depth); // Brightness: ~15% bright particles currently, boost to 20% on speaking peaks final brightThreshold = state == VoiceState.speaking     ? 0.80 - amplitude * 0.12   // more bright particles on loud beats    : 0.85; final isBright = rng.nextDouble() > brightThreshold; // On speaking state, brief particle "flash" on amplitude spikes > 0.8 final flashBoost = (state == VoiceState.speaking && amplitude > 0.8)     ? 0.25 * (amplitude - 0.8) / 0.2    : 0.0; final finalOpacity = (opacity + flashBoost).clamp(0.0, 1.0);`

## 2g — Soft Inner Glow Through Particles

Draw a soft radial glow behind the particles (before the particle loop):

dart

`// Before the particle for-loop in paint(): final glowStrength = switch (state) {   VoiceState.idle      => 0.06,  VoiceState.listening => 0.10 + amplitude * 0.08,  VoiceState.thinking  => 0.05,  VoiceState.speaking  => 0.08 + amplitude * 0.12, }; final glowPaint = Paint()   ..shader = RadialGradient(    colors: [      (isCool ? const Color(0xFF00AACC) : const Color(0xFFC05621))          .withValues(alpha: glowStrength),      Colors.transparent,    ],  ).createShader(Rect.fromCircle(    center: Offset(cx, cy),    radius: effectiveRadius * 0.65,  )); canvas.drawCircle(Offset(cx, cy), effectiveRadius * 0.65, glowPaint);`

---

## TASK 3 — State Transition Animations (Smooth Morphing)

## Currently: instant color swap. Target: physical, spring-like transitions.

## 3a — Animated State Values

Instead of switching state directly, interpolate key values across state  
changes using `AnimationController` + `Tween`:

dart

`// Add a single "state energy" value that lerps between states: late AnimationController _stateTransitionCtrl; late Animation<double> _energyAnim; // 0.0=calm, 1.0=active // When state changes, drive _stateTransitionCtrl forward or reverse: void _onStateChanged(VoiceState newState) {   setState(() => _voiceState = newState);  switch (newState) {    case VoiceState.idle:      _stateTransitionCtrl.animateTo(0.0,          duration: const Duration(milliseconds: 800),          curve: Curves.easeOut);    case VoiceState.listening:      _stateTransitionCtrl.animateTo(1.0,          duration: const Duration(milliseconds: 400),          curve: Curves.easeIn);    case VoiceState.thinking:      _stateTransitionCtrl.animateTo(0.3,          duration: const Duration(milliseconds: 600),          curve: Curves.easeInOut);    case VoiceState.speaking:      _stateTransitionCtrl.animateTo(0.75,          duration: const Duration(milliseconds: 500),          curve: Curves.easeOut);  } }`

Use `_stateTransitionCtrl.value` to blend `turbStrength`, `breathScale`, and  
rotation speed rather than hard switching — this gives smooth morphing.

## 3b — Orb Size/Position Transition Sequencing

**Critical fix from screenshots:** The orb must finish shrinking to the  
bottom BEFORE the text starts fading in. Currently they happen simultaneously.

dart

`// Replace simultaneous animation with a chained sequence: Future<void> _enterSpeakingState(String text) async {   // Step 1: orb shrinks and moves to bottom (550ms)  setState(() => _hasResponseText = true); // triggers AnimatedAlign  await Future.delayed(const Duration(milliseconds: 500));   // Step 2: THEN text fades in (450ms)  _displayText = text;  _textFadeCtrl.forward(); }`

## 3c — Cool/Warm Background Transition Timing

From the screenshots, when AI starts speaking the background shifts to a  
**dark teal from the bottom** — it's not just a gradient color change, it  
reads as a teal atmospheric glow rising up.

The existing `AnimatedContainer` with 700ms is close but enhance it:

dart

`// Use a curved 900ms transition for the background AnimatedContainer(   duration: const Duration(milliseconds: 900),  curve: Curves.easeInOut,  decoration: BoxDecoration(    gradient: RadialGradient(      center: Alignment.bottomCenter,      radius: 1.4,      colors: _isCoolState          ? [const Color(0xFF001A26), Colors.black]          : [const Color(0xFF3A1F00), Colors.black],      stops: const [0.0, 1.0],    ),  ), )`

---

## TASK 4 — Word-by-Word Text Streaming with Live Word Highlight

## Currently: full text fades in at once.

## 4a — Word Stream Controller

dart

`// State variables to add: List<String> _words = []; int _revealedWordCount = 0; Timer? _wordTimer;`
Continuing exactly from where the MD file was cut off — Task 4 onwards:

text

`// State variables to add: List<String> _words = []; int _revealedWordCount = 0; Timer? _wordTimer; // Call this instead of setting _displayText directly: void _streamWords(String fullText) {   _words = fullText.split(' ');  _revealedWordCount = 0;  _wordTimer?.cancel();   // Vary delay per word to feel like natural speech rhythm:  // Short words (≤3 chars) come faster, long words slightly slower.  void scheduleNext() {    if (_revealedWordCount >= _words.length) {      _wordTimer = null;      return;    }    final word = _words[_revealedWordCount];    final delay = word.length <= 3        ? const Duration(milliseconds: 110)        : word.length <= 6            ? const Duration(milliseconds: 160)            : const Duration(milliseconds: 210);     _wordTimer = Timer(delay, () {      if (!mounted) return;      setState(() => _revealedWordCount++);      scheduleNext();    });  }   scheduleNext(); } // Cancel safely on state exit: void _cancelWordStream() {   _wordTimer?.cancel();  _wordTimer = null;  _words = [];  _revealedWordCount = 0; }`

## 4b — Word-by-Word RichText Renderer

Replace the current single `Text` widget that renders `_displayText` with  
this `_buildStreamingText()` method:

dart

`Widget _buildStreamingText() {   if (_words.isEmpty) return const SizedBox.shrink();   final spans = <InlineSpan>[];   for (int i = 0; i < _revealedWordCount; i++) {    final word = _words[i];    final isLastRevealed = i == _revealedWordCount - 1;    final isStreamComplete = _revealedWordCount >= _words.length;     // Last actively-streaming word: bold + bright white + slightly larger    // Once streaming is complete, all words settle to the same style    if (isLastRevealed && !isStreamComplete) {      spans.add(        TextSpan(          text: '$word ',          style: const TextStyle(            fontSize: 31,            // slightly larger than base 29            fontWeight: FontWeight.w600,            color: Color(0xFFFFFFFF), // pure white — "being spoken now"            height: 1.35,          ),        ),      );    } else {      // Already-spoken words: muted grey, normal weight      spans.add(        TextSpan(          text: '$word ',          style: const TextStyle(            fontSize: 29,            fontWeight: FontWeight.w300,            color: Color(0xFFCCCCCC), // matches existing text color            height: 1.35,          ),        ),      );    }  }   return RichText(    text: TextSpan(children: spans),    textAlign: TextAlign.left,  ); }`

## 4c — Animate the Last Word Fade-In

Each new word should pop in with a micro fade rather than appearing  
instantly. Wrap the `_buildStreamingText` widget in an `AnimatedSwitcher`  
keyed to `_revealedWordCount`:

dart

`// Replace static text widget with: AnimatedSwitcher(   duration: const Duration(milliseconds: 80),  transitionBuilder: (child, animation) => FadeTransition(    opacity: animation,    child: child,  ),  child: KeyedSubtree(    key: ValueKey(_revealedWordCount),    child: _buildStreamingText(),  ), )`

## 4d — Wire _streamWords Into the Demo Flow

Find the existing `runDemoFlow` and replace the `_displayText` assignment:

dart

`// BEFORE (existing): // setState(() => _displayText = 'Hey there! How can I help you today?'); // AFTER: await _enterSpeakingState(   'Hey there! How can I help you today?' ); // Inside _enterSpeakingState (from Task 3b), after the orb shrinks: void _enterSpeakingState(String text) async {   setState(() => _hasResponseText = true);  await Future.delayed(const Duration(milliseconds: 500)); // orb moves first  _streamWords(text); // then words stream in }`

## 4e — Clean Up on Exit

In `exitVoice` and whenever state returns to idle, call `_cancelWordStream()`  
and clear text:

dart

`void _resetToIdle() {   _cancelWordStream();  setState(() {    _displayText = '';    _words = [];    _revealedWordCount = 0;    _hasResponseText = false;  });  _textFadeCtrl.reverse(); }`

---

## TASK 5 — Button Opacity on Speaking State

## Observed in screenshots: buttons near-invisible when AI is speaking.

## Currently: buttons always at full opacity.

dart

`// Wrap the entire bottom button Row with AnimatedOpacity: AnimatedOpacity(   duration: const Duration(milliseconds: 600),  curve: Curves.easeInOut,  // Buttons fade to 15% during speaking, full opacity otherwise  opacity: _voiceState == VoiceState.speaking ? 0.15 : 1.0,  child: Row(    // ... existing X button, orb, mic button  ), )`

Also individually fade the X button and mic button with a slight delay  
offset to stagger the fade — makes it feel more intentional:

dart

`// X button wrapper: AnimatedOpacity(   duration: const Duration(milliseconds: 500),  opacity: _voiceState == VoiceState.speaking ? 0.12 : 1.0,  child: _buildCloseButton(), ) // Mic button wrapper — slightly delayed via a bool toggled 150ms after state: AnimatedOpacity(   duration: const Duration(milliseconds: 500),  opacity: _voiceState == VoiceState.speaking ? 0.12 : 1.0,  child: _buildMicButton(), )`

---

## TASK 6 — Mini Orb (Bottom Bar) Color State Matching

## Observed in screenshots: mini orb color matches background state perfectly.

## The cool/warm palette switch already exists — this task ensures the

## mini orb TRANSITIONS its color smoothly, not instantly.

The `SpherePainter` already uses `isCool` based on state — no color change  
needed. But the transition feels instant because it reads `state` directly.

**Fix:** Pass the `_stateTransitionCtrl.value` (from Task 3a) as a blend  
parameter into `SpherePainter` so both the main orb and mini orb morph  
their color gradually:

dart

`// Add to SpherePainter: final double stateBlend; // 0.0 = fully warm, 1.0 = fully cool // In paint(), replace hard isCool switch with blended color: final warmBase  = const Color(0xFFC05621); final coolBase  = const Color(0xFF00AACC); final warmBright = const Color(0xFFFFCB8A); final coolBright = const Color(0xFF88EEFF); Color _lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t)!; final base   = _lerpColor(warmBase,   coolBase,   stateBlend); final bright = _lerpColor(warmBright, coolBright, stateBlend);`

Pass `stateBlend` from the parent using `_stateTransitionCtrl.value` for  
listening/thinking states and a derived value for speaking:

dart

`// In build(), compute stateBlend: final stateBlend = switch (_voiceState) {   VoiceState.idle      => 0.0,  VoiceState.listening => _stateTransitionCtrl.value,       // 0→1  VoiceState.thinking  => _stateTransitionCtrl.value * 0.4, // subtle cool  VoiceState.speaking  => 0.0, // warm — speaking is warm per app theme };`

---

## TASK 7 — "Say Something..." Label Enhancements

## Currently: single label with opacity animation.

## Target: label text changes per state with crossfade.

dart

`// Replace static label string with state-aware getter: String get _statusLabel => switch (_voiceState) {   VoiceState.idle      => 'Say something...',  VoiceState.listening => 'Listening...',  VoiceState.thinking  => 'Thinking...',  VoiceState.speaking  => '',  // hide during speaking — text is top-left }; // Wrap label in AnimatedSwitcher for crossfade between label strings: AnimatedSwitcher(   duration: const Duration(milliseconds: 300),  transitionBuilder: (child, anim) => FadeTransition(    opacity: anim,    child: SlideTransition(      position: Tween<Offset>(        begin: const Offset(0, 0.3),        end: Offset.zero,      ).animate(CurvedAnimation(parent: anim as AnimationController,          curve: Curves.easeOut)),      child: child,    ),  ),  child: Text(    _statusLabel,    key: ValueKey(_statusLabel),    style: TextStyle(      fontSize: 16,      fontWeight: FontWeight.w300,      color: Colors.white.withValues(alpha: 0.55),      letterSpacing: 0.3,    ),  ), )`

> **Note:** `SlideTransition` inside `AnimatedSwitcher` requires the anim  
> parameter to be cast. Alternatively use a simpler `FadeTransition` only if  
> the slide causes type issues — the fade alone is sufficient.

---

## TASK 8 — Background Gradient: Teal Rises From Bottom

## Observed in screenshots: speaking state has a distinct teal atmospheric

## glow that RISES from the bottom of the screen — not a centered radial.

## Currently: `RadialGradient` from `bottomCenter` which is close but the

## teal feels too spread. Fix the gradient stops for more accuracy.

dart

`// Speaking/listening state gradient — teal rises like a fog from bottom: RadialGradient(   center: Alignment.bottomCenter,  radius: 1.1,          // tighter — keeps teal low on screen  colors: [    const Color(0xFF002233), // deep teal at bottom    const Color(0xFF001020), // mid teal    Colors.black,            // pure black at top  ],  stops: const [0.0, 0.45, 1.0], ) // Idle/speaking (warm) state — amber glow stays at bottom third: RadialGradient(   center: Alignment.bottomCenter,  radius: 1.0,  colors: [    const Color(0xFF3A1F00), // warm amber    const Color(0xFF1A0D00), // dark amber    Colors.black,  ],  stops: const [0.0, 0.5, 1.0], )`

---

## TASK 9 — Performance: Keep 800 Particles at 60fps on Mid-Range Android

## Tecno/Infinix class devices — ~2GB RAM, Mali GPU.

## 9a — Zero Allocations Inside paint()

The current implementation creates `Paint()` inside the loop every frame.  
This causes GC pressure at 60fps × 800 particles = 48,000 allocations/sec.

dart

`// In SpherePainter, declare reusable paint object as field: final Paint _particlePaint = Paint()..style = PaintingStyle.fill; // Inside paint loop, reuse it — just set color: _particlePaint.color = color; canvas.drawCircle(Offset(x, y), dotSize, _particlePaint); // Also reuse for glow: final Paint _glowPaint = Paint(); // Set shader once before drawCircle, reuse object`

## 9b — Avoid Per-Frame Random Reconstruction

The `Random(42)` is already a fixed seed which is correct. But ensure it is  
constructed **once as a field**, not inside `paint()`:

dart

`// In SpherePainter — declare as field: static final Random _rng = Random(42); // paint() uses _rng directly — no reconstruction each frame`

## 9c — RepaintBoundary Isolation

Wrap the `CustomPaint` (sphere) in a `RepaintBoundary` so particle repaints  
do not trigger repaints on the text or background layers:

dart

`RepaintBoundary(   child: AnimatedBuilder(    animation: Listenable.merge([      _sphereCtrl, _breathCtrl, _timeCtrl    ]),    builder: (context, _) {      return CustomPaint(        painter: SpherePainter(          progress:     _sphereCtrl.value,          state:        _voiceState,          amplitude:    _amplitude,          elapsed:      _elapsed,          breathScale:  _breathScale,          stateBlend:   _stateBlend,        ),        size: Size(orbSize, orbSize),      );    },  ), )`

## 9d — Particle Count Scaling by Device Performance

Add a simple heuristic to drop particle count on slower devices:

dart

`// Detect available logical processors as a proxy for device tier: int get _particleCount {   // Platform.numberOfProcessors is available in dart:io  // 4 cores or fewer = low tier device → use 500 particles  // 6+ cores = mid/high tier → use 800 particles  try {    return Platform.numberOfProcessors <= 4 ? 500 : 800;  } catch (_) {    return 800; // default  } }`

Pass `_particleCount` to `SpherePainter` as the `count` override:

dart

`final count = dense ? 300 : widget.particleCount;`

## 9e — Throttle _AmplitudeEngine Reads

Do not read `_amplitude` from `_timeCtrl` every build — throttle to 30fps  
for the amplitude value while keeping sphere rotation at 60fps:

dart

`double _cachedAmplitude = 0.0; int _ampFrameCount = 0; // In AnimatedBuilder builder: _ampFrameCount++; if (_ampFrameCount % 2 == 0) { // every other frame = 30fps amplitude   _cachedAmplitude = _AmplitudeEngine.getValue(_elapsed, _voiceState); } // Pass _cachedAmplitude to painter, not _amplitude directly`

---

## TASK 10 — Thinking State: Spiral Contraction Effect

## Currently: only color changes. Target: wormhole/inward spiral feel.

Add a `spiralOffset` computation in the painter for thinking state only:

dart

`// Inside paint loop, thinking state only: if (state == VoiceState.thinking) {   // Pull particles toward center based on their current z-depth  // Front-facing particles (high z) get pulled more → spiral inward  final pullStrength = 0.18 * (1.0 - stateTransitionBlend);  final spiralAngle = elapsed * 2.0 + (i * 0.05);  final pullX = cos(spiralAngle) * pullStrength * radius;  final pullY = sin(spiralAn`

Continuing exactly from where Task 10 was cut off:

text

  `final pullY = sin(spiralAngle) * pullStrength * radius;   // Apply pull toward center — stronger for front-facing particles  final depthFactor = (depth * 0.7).clamp(0.0, 1.0);  final x_final = x + pullX * depthFactor;  final y_final = y + pullY * depthFactor;   // Use x_final, y_final instead of x, y for drawCircle in thinking state }`

Full thinking state paint override — wrap the existing `drawCircle` call:

dart

`final drawX = state == VoiceState.thinking     ? x + (cos(elapsed * 2.0 + i * 0.05) * 0.18 * radius * depth)    : x; final drawY = state == VoiceState.thinking     ? y + (sin(elapsed * 2.0 + i * 0.05) * 0.18 * radius * depth)    : y; canvas.drawCircle(Offset(drawX, drawY), dotSize, _particlePaint);`

## 10b — Thinking State: Radius Contraction Over Time

As the device enters thinking state, particles should visually contract  
inward over ~600ms, then hold the contracted state, then release when  
speaking begins. Use the `_stateTransitionCtrl` value from Task 3a:

dart

`// In SpherePainter, add parameter: final double thinkingContraction; // 0.0=full size, 1.0=fully contracted // In paint(): final contractionFactor = 1.0 - (thinkingContraction * 0.28); // 0.28 = contracts to 72% of original radius at peak thinking final effectiveRadius = (size.width / 2) * breathScale * contractionFactor;`

Drive `thinkingContraction` from the State widget:

dart

`// Add controller: late AnimationController _thinkCtrl; // Init: _thinkCtrl = AnimationController(   vsync: this,  duration: const Duration(milliseconds: 650), ); // In _onStateChanged(): case VoiceState.thinking:   _thinkCtrl.animateTo(1.0,      duration: const Duration(milliseconds: 650),      curve: Curves.easeInOut); case VoiceState.speaking: // releases contraction when speaking starts   _thinkCtrl.animateTo(0.0,      duration: const Duration(milliseconds: 400),      curve: Curves.easeOut); case VoiceState.idle:   _thinkCtrl.animateTo(0.0,      duration: const Duration(milliseconds: 300),      curve: Curves.easeOut); case VoiceState.listening:   _thinkCtrl.animateTo(0.0,      duration: const Duration(milliseconds: 250),      curve: Curves.easeOut);`

## 10c — Thinking State: Slow Rotation Rings (Halo Effect)

Draw 2 faint concentric ring halos that rotate in opposite directions  
during thinking — like the energy is being focused and wound up:

dart

`// Add this method to SpherePainter, called in paint() during thinking: void _drawThinkingHalos(Canvas canvas, Offset center, double radius,     double elapsed, double contraction) {  if (contraction < 0.05) return; // skip if barely in thinking state   final haloRadius1 = radius * 0.85 * (1.0 - contraction * 0.15);  final haloRadius2 = radius * 1.05 * (1.0 - contraction * 0.10);   // Ring 1 — rotates clockwise  final sweepAngle1 = elapsed * 1.2; // radians  final haloOpacity1 = (contraction * 0.25).clamp(0.0, 0.25);  _drawArcRing(canvas, center, haloRadius1, sweepAngle1,      const Color(0xFF00AACC), haloOpacity1);   // Ring 2 — rotates counter-clockwise, slightly larger  final sweepAngle2 = -elapsed * 0.8;  final haloOpacity2 = (contraction * 0.15).clamp(0.0, 0.15);  _drawArcRing(canvas, center, haloRadius2, sweepAngle2,      const Color(0xFF88EEFF), haloOpacity2); } void _drawArcRing(Canvas canvas, Offset center, double radius,     double startAngle, Color color, double opacity) {  final paint = Paint()    ..color = color.withValues(alpha: opacity)    ..style = PaintingStyle.stroke    ..strokeWidth = 1.2    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);   // Draw a nearly-complete arc (330 degrees) for a ring-gap aesthetic  canvas.drawArc(    Rect.fromCircle(center: center, radius: radius),    startAngle,    5.76, // 330 degrees in radians    false,    paint,  ); }`

Call inside `paint()` after the particle loop:

dart

`// After for-loop, before returning: if (state == VoiceState.thinking) {   _drawThinkingHalos(canvas, Offset(cx, cy), effectiveRadius,      elapsed, thinkingContraction); }`

---

## TASK 11 — Listening State: Outward Particle Wave Bursts

## Currently: color swap + slightly faster rotation.

## Target: particles pulse outward in concentric waves from center,

## reacting to the fake amplitude signal.

## 11a — Wave Displacement

Each particle gets displaced radially outward based on a wave function  
that travels from the center outward over time:

dart

`// Inside paint loop, after computing final x, y positions: if (state == VoiceState.listening) {   // Each particle has a natural "distance from center" on the sphere surface  // Use phi (polar angle) as a proxy for distance from equator:  // Wave travels from equator outward, amplitude-driven   final waveSpeed  = 2.8;   // wave travels across sphere in ~0.35s  final waveTime   = elapsed * waveSpeed;  // Use particle index as a phase offset so wave is not uniform:  final particlePhase = (i / count) * 2 * pi;  final waveValue  = sin(waveTime + particlePhase);   // Amplitude gate: wave only visible above 0.2 amplitude  final waveStrength = amplitude > 0.2      ? (amplitude - 0.2) / 0.8 * 7.0  // max 7px outward push      : 0.0;   // Push particle radially outward from center of canvas:  final dx = drawX - cx;  final dy = drawY - cy;  final dist = sqrt(dx * dx + dy * dy);  if (dist > 0.001) {    final pushX = (dx / dist) * waveValue * waveStrength;    final pushY = (dy / dist) * waveValue * waveStrength;    // Apply push    canvas.drawCircle(      Offset(drawX + pushX, drawY + pushY),      dotSize,      _particlePaint,    );    continue; // skip the default drawCircle below  } } // Default draw (all other states): canvas.drawCircle(Offset(drawX, drawY), dotSize, _particlePaint);`

> **Performance note:** The `sqrt` call per particle is acceptable since it  
> only runs during listening state. On idle/thinking/speaking the branch is  
> skipped entirely.

## 11b — Pulse Ring Emit on Amplitude Spikes

When amplitude crosses 0.65 threshold, emit a single expanding ring from  
the orb center. Rings expand outward and fade out over ~0.5s.

dart

`// Add to State widget: final List<_PulseRing> _pulseRings = []; double _lastAmplitude = 0.0; // Add this data class above the State: class _PulseRing {   final double birthTime; // elapsed seconds when created  _PulseRing(this.birthTime); } // In the AnimatedBuilder / build loop, check for amplitude threshold: void _checkPulseEmit() {   final amp = _cachedAmplitude;  // Emit on rising edge crossing 0.65 — not on sustained high  if (amp > 0.65 && _lastAmplitude <= 0.65) {    _pulseRings.add(_PulseRing(_elapsed));    // Max 4 rings alive at once to avoid clutter    if (_pulseRings.length > 4) _pulseRings.removeAt(0);  }  _lastAmplitude = amp; } // Draw pulse rings in paint() or as a separate widget layer: // Preferably as a separate CustomPainter on top of the sphere for // clean separation. Create PulseRingPainter: class _PulseRingPainter extends CustomPainter {   final List<_PulseRing> rings;  final double elapsed;  final double maxRadius; // matches orb radius   const _PulseRingPainter({    required this.rings,    required this.elapsed,    required this.maxRadius,  });   @override  void paint(Canvas canvas, Size size) {    final cx = size.width / 2;    final cy = size.height / 2;    final paint = Paint()      ..style = PaintingStyle.stroke      ..strokeWidth = 1.5;     for (final ring in rings) {      final age = elapsed - ring.birthTime;         // 0.0→∞ seconds      if (age > 0.7) continue;                      // ring lives 0.7s       final progress = age / 0.7;                   // 0.0→1.0      final ringRadius = maxRadius * (1.0 + progress * 0.6); // expands 60%      final opacity = (1.0 - progress) * 0.4;       // fades out       paint.color = const Color(0xFF00AACC).withValues(alpha: opacity);      canvas.drawCircle(Offset(cx, cy), ringRadius, paint);    }  }   @override  bool shouldRepaint(_PulseRingPainter old) =>      old.elapsed != elapsed || old.rings != rings; }`

Place `PulseRingPainter` as a widget above the main sphere in the Stack:

dart

`// In the Stack, above the sphere CustomPaint: if (_voiceState == VoiceState.listening)   CustomPaint(    painter: _PulseRingPainter(      rings:     _pulseRings,      elapsed:   _elapsed,      maxRadius: _orbSize / 2,    ),    size: Size(_orbSize, _orbSize),  ),`

---

## TASK 12 — Speaking State: Surface Undulation on TTS Beats

## Currently: global 0.95→1.05 scale pulse only.

## Target: surface displacement mapped to fake TTS amplitude rhythm,

## particles push outward on stressed syllables.

## 12a — Beat Detection From Amplitude Engine

A "beat" is when amplitude crosses a rising threshold. Track it:

dart

`// Add to State widget: double _lastSpeakingAmp = 0.0; double _beatStrength = 0.0;       // decays between beats double _beatDecayStart = 0.0;     // elapsed time when beat was detected void _updateBeatDetection() {   if (_voiceState != VoiceState.speaking) {    _beatStrength = 0.0;    return;  }  final amp = _cachedAmplitude;  // Rising edge: was below 0.6, now above 0.6 = a stressed syllable  if (amp > 0.60 && _lastSpeakingAmp <= 0.60) {    _beatStrength = 1.0;           // full beat strength    _beatDecayStart = _elapsed;  }  // Decay beat strength over 0.25s  final beatAge = _elapsed - _beatDecayStart;  _beatStrength = (1.0 - beatAge / 0.25).clamp(0.0, 1.0);  _lastSpeakingAmp = amp; }`

## 12b — Pass Beat Strength to SpherePainter

Add `beatStrength` parameter to `SpherePainter`:

dart

`final double beatStrength; // 0.0→1.0, decays between syllable beats`

Use it to push particles outward on beats — similar to the listening wave  
but faster, sharper, and applied uniformly rather than as a traveling wave:

dart

`// Inside paint loop, speaking state: if (state == VoiceState.speaking && beatStrength > 0.0) {   // Sharp outward push proportional to beat strength  // Decays quickly → snap-back feel (like a drum hit)  final beatPush = beatStrength * 9.0 * depth; // front particles push more   final dx = drawX - cx;  final dy = drawY - cy;  final dist = sqrt(dx * dx + dy * dy);  if (dist > 0.001) {    final pushX = (dx / dist) * beatPush;    final pushY = (dy / dist) * beatPush;    canvas.drawCircle(      Offset(drawX + pushX, drawY + pushY),      dotSize * (1.0 + beatStrength * 0.4), // particles also enlarge on beat      _particlePaint,    );    continue;  } }`

## 12c — Brightness Flash on Stressed Syllables

On beat, briefly boost particle brightness. Modify the `isBright` check:

dart

`// Replace existing isBright threshold: final beatBrightnessBoost = state == VoiceState.speaking     ? beatStrength * 0.20  // up to 20% more bright particles on a beat    : 0.0; final brightThreshold = 0.85 - beatBrightnessBoost; final isBright = rng.nextDouble() > brightThreshold;`

---

## TASK 13 — Listening State: Mic Waveform Indicator

## An enhancement NOT in the original MD.

## When listening, show a subtle 3-bar waveform indicator near the

## bottom "Listening..." label — visually confirms mic is active.

## Pure Flutter, no packages.

dart

`// Add this widget method to the State: Widget _buildMicWaveform() {   if (_voiceState != VoiceState.listening) return const SizedBox.shrink();   return AnimatedBuilder(    animation: _timeCtrl,    builder: (context, _) {      final t = _elapsed;      // 3 bars with different heights driven by sine waves at different phases      final h1 = 6.0 + 10.0 * ((sin(t * 8.0 + 0.0) + 1) / 2);      final h2 = 6.0 + 14.0 * ((sin(t * 9.3 + 1.0) + 1) / 2);      final h3 = 6.0 + 10.0 * ((sin(t * 7.6 + 2.1) + 1) / 2);      final h4 = 6`

Continuing exactly from where Task 13 was cut off:

text

      `final h4 = 6.0 + 12.0 * ((sin(t * 10.1 + 3.2) + 1) / 2);      final h5 = 6.0 + 10.0 * ((sin(t * 8.7 + 4.0) + 1) / 2);       // Bar width and spacing      const barW   = 3.0;      const gap    = 5.0;      const totalW = barW * 5 + gap * 4; // 35px total width       return SizedBox(        width: totalW,        height: 28.0, // max bar height container        child: Row(          mainAxisAlignment: MainAxisAlignment.center,          crossAxisAlignment: CrossAxisAlignment.center,          children: [            _buildBar(h1, barW),            const SizedBox(width: gap),            _buildBar(h2, barW),            const SizedBox(width: gap),            _buildBar(h3, barW),            const SizedBox(width: gap),            _buildBar(h4, barW),            const SizedBox(width: gap),            _buildBar(h5, barW),          ],        ),      );    },  ); } Widget _buildBar(double height, double width) {   return AnimatedContainer(    duration: const Duration(milliseconds: 60),    width: width,    height: height,    decoration: BoxDecoration(      color: const Color(0xFF00AACC).withValues(alpha: 0.75),      borderRadius: BorderRadius.circular(barW / 2),    ),  ); }`

## 13b — Place Waveform in Layout

Position the waveform directly above the "Listening..." label text, centered:

dart

`// In voice mode layout Stack, replace the plain label section with: Positioned(   bottom: 168, // sits just above the bottom bar orb row  left: 0,  right: 0,  child: Column(    mainAxisSize: MainAxisSize.min,    children: [       // Waveform bars — only visible during listening      AnimatedSwitcher(        duration: const Duration(milliseconds: 350),        transitionBuilder: (child, anim) => FadeTransition(          opacity: anim,          child: child,        ),        child: _voiceState == VoiceState.listening            ? _buildMicWaveform()            : const SizedBox(height: 28, key: ValueKey('empty')),      ),       const SizedBox(height: 10),       // Status label (from Task 7)      AnimatedSwitcher(        duration: const Duration(milliseconds: 300),        child: Text(          _statusLabel,          key: ValueKey(_statusLabel),          style: TextStyle(            fontSize: 16,            fontWeight: FontWeight.w300,            color: Colors.white.withValues(alpha: 0.55),            letterSpacing: 0.3,          ),        ),      ),    ],  ), ),`

## 13c — Amplitude-Driven Bar Heights

Once real STT amplitude is wired, replace the sine-based heights with  
actual amplitude data. Design the bars to accept an optional amplitude  
override so swapping is one line:

dart

`// Enhanced _buildMicWaveform accepting optional real amplitude: Widget _buildMicWaveform({double? realAmplitude}) {   return AnimatedBuilder(    animation: _timeCtrl,    builder: (context, _) {      final t = _elapsed;       // If real amplitude available, scale bar heights proportionally.      // Otherwise fall back to pure sine-wave simulation.      final scale = realAmplitude ?? _cachedAmplitude;       final h1 = 6.0 + (10.0 * scale) * ((sin(t * 8.0 + 0.0) + 1) / 2);      final h2 = 6.0 + (14.0 * scale) * ((sin(t * 9.3 + 1.0) + 1) / 2);      final h3 = 6.0 + (14.0 * scale) * ((sin(t * 7.6 + 2.1) + 1) / 2);      final h4 = 6.0 + (12.0 * scale) * ((sin(t * 10.1 + 3.2) + 1) / 2);      final h5 = 6.0 + (10.0 * scale) * ((sin(t * 8.7 + 4.0) + 1) / 2);       const barW  = 3.0;      const gap   = 5.0;      const totalW = barW * 5 + gap * 4;       return SizedBox(        width: totalW,        height: 28.0,        child: Row(          mainAxisAlignment: MainAxisAlignment.center,          crossAxisAlignment: CrossAxisAlignment.center,          children: [            _buildBar(h1, barW),            const SizedBox(width: gap),            _buildBar(h2, barW),            const SizedBox(width: gap),            _buildBar(h3, barW),            const SizedBox(width: gap),            _buildBar(h4, barW),            const SizedBox(width: gap),            _buildBar(h5, barW),          ],        ),      );    },  ); }`

---

## TASK 14 — Entry Animation: Voice Mode Fade-In Polish

## NOT in original MD. Currently voice overlay just fades in (350ms).

## Target: the orb should MATERIALIZE — particles coalesce from nothing

## into the sphere shape, like the orb is assembling itself.

## 14a — Entry Scale + Opacity Cascade

On `enterVoice()`, run a 3-stage entry sequence:

dart

`Future<void> enterVoice() async {   // Stage 1: fade in the background gradient first (200ms)  setState(() => _aiMode = AiMode.voice);  _modeCtrl.forward();  await Future.delayed(const Duration(milliseconds: 200));   // Stage 2: orb materializes — scale from 0.3 → 1.0 with overshoot  _orbEntryCtrl.forward(); // new controller (see below)  await Future.delayed(const Duration(milliseconds: 450));   // Stage 3: hint text fades in last  _hintTextVisible = true;  setState(() {}); }`

Add a dedicated entry controller:

dart

`late AnimationController _orbEntryCtrl; late Animation<double> _orbEntryScale; late Animation<double> _orbEntryOpacity; // Init: _orbEntryCtrl = AnimationController(   vsync: this,  duration: const Duration(milliseconds: 700), ); // Bouncy scale: starts at 0.3, overshoots to 1.08, settles at 1.0 _orbEntryScale = TweenSequence<double>([   TweenSequenceItem(    tween: Tween(begin: 0.3, end: 1.08)        .chain(CurveTween(curve: Curves.easeOut)),    weight: 70,  ),  TweenSequenceItem(    tween: Tween(begin: 1.08, end: 1.0)        .chain(CurveTween(curve: Curves.easeIn)),    weight: 30,  ), ]).animate(_orbEntryCtrl); // Opacity: 0.0 → 1.0 over first 60% of duration _orbEntryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(   CurvedAnimation(    parent: _orbEntryCtrl,    curve: const Interval(0.0, 0.6, curve: Curves.easeIn),  ), ); // Reset on exit: void exitVoice() {   _orbEntryCtrl.reverse();  // ... existing exit logic }`

Apply to the orb widget:

dart

`AnimatedBuilder(   animation: _orbEntryCtrl,  builder: (context, child) {    return Transform.scale(      scale: _orbEntryScale.value,      child: Opacity(        opacity: _orbEntryOpacity.value,        child: child,      ),    );  },  child: CustomPaint(    painter: SpherePainter( /* ... */ ),    size: Size(_orbSize, _orbSize),  ), )`

## 14b — Particle Density Ramp-Up on Entry

Pass an `entryProgress` (0.0→1.0) to `SpherePainter` during entry so  
particles appear to coalesce — early in entry only a fraction are visible:

dart

`// Add parameter to SpherePainter: final double entryProgress; // 1.0 = fully materialized, default 1.0 // In paint loop: // Skip particles whose index is above the threshold — // they "appear" progressively as entryProgress increases final visibleCount = (count * entryProgress).round(); for (int i = 0; i < visibleCount; i++) {   // ... existing loop body unchanged }`

Wire from State:

dart

`// In build: final entryProgress = _orbEntryCtrl.isAnimating || _orbEntryCtrl.value < 1.0     ? _orbEntryCtrl.value    : 1.0; // Pass to SpherePainter: SpherePainter(   // ... existing params  entryProgress: entryProgress, )`

---

## TASK 15 — Exit Animation: Orb Dissolves Out

## NOT in original MD. Currently voice mode just fade-reverses.

## Target: orb should dematerialize — particles scatter outward and

## fade, not just disappear with the overlay.

dart

`Future<void> exitVoice() async {   // Stage 1: scatter particles outward (300ms)  setState(() => _isExiting = true); // flag for painter  await Future.delayed(const Duration(milliseconds: 300));   // Stage 2: fade out overlay  _modeCtrl.reverse();  await Future.delayed(const Duration(milliseconds: 350));   // Stage 3: fully clean up  setState(() {    _aiMode = AiMode.text;    _isExiting = false;    _voiceState = VoiceState.idle;  });  _resetToIdle();  _orbEntryCtrl.reset(); }`

Add `isExiting` to `SpherePainter`:

dart

`final bool isExiting; // In paint loop, if isExiting scatter particles: if (isExiting) {   // Push each particle radially outward from center rapidly  final scatterStrength = 35.0 * (1.0 - entryProgress); // reuse entry anim  final dx = drawX - cx;  final dy = drawY - cy;  final dist = sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);  final scatterX = drawX + (dx / dist) * scatterStrength;  final scatterY = drawY + (dy / dist) * scatterStrength;  // Fade opacity toward 0 during exit  _particlePaint.color = color.withValues(    alpha: (opacity * entryProgress).clamp(0.0, 1.0),  );  canvas.drawCircle(Offset(scatterX, scatterY), dotSize, _particlePaint);  continue; }`

Drive `entryProgress` in reverse for exit — reuse `_orbEntryCtrl.reverse()`  
so `entryProgress` counts down from 1.0 → 0.0 during the scatter phase.

---

## TASK 16 — Idle State: Slow Ambient Particle Drift

## NOT in original MD. Perplexity's idle orb is never truly still —

## particles have a barely perceptible slow drift, like the orb is

## breathing cosmically. Currently just constant rotation.

## 16a — Secondary Slow Rotation Axis (X-axis tilt)

Add a very slow X-axis rotation oscillation to make the orb feel like it  
is gently tilting and breathing in 3D:

dart

`// Add to SpherePainter parameters: final double idleTiltX; // 0.0→1.0, driven by breathCtrl during idle // In paint(), after rotY is computed: // Apply a subtle X-axis rotation during idle — max ±8 degrees final rotX = (state == VoiceState.idle)     ? sin(idleTiltX * 2 * pi) * 0.14  // ±0.14 radians = ±8 degrees    : 0.0; // Apply rotX to the already-rotated position (x after rotY): // Rotate (x_rotated, y) around X axis: final x_r = x - cx; // relative to center final y_r = y - cy; final x_tilt = cx + x_r; final y_tilt = cy + (y_r * cos(rotX) - z * sin(rotX)); // Use x_tilt, y_tilt as final draw position during idle final finalDrawX = (state == VoiceState.idle) ? x_tilt : drawX; final finalDrawY = (state == VoiceState.idle) ? y_tilt : drawY;`

Wire `idleTiltX` from `_breathCtrl` in the parent:

dart

`// In build(): final idleTiltX = _voiceState == VoiceState.idle     ? _breathCtrl.value   // 0.0→1.0 over 3.2s, reversing    : 0.0;`

## 16b — Ambient Particle Twinkle

During idle, random particles briefly brighten and dim — like stars  
twinkling. Fully deterministic using the fixed seed + elapsed:

dart

`// In paint loop, idle state only: if (state == VoiceState.idle) {   // Each particle has a unique twinkle phase based on index  final twinklePhase = (i * 0.618) % (2 * pi); // golden ratio spread  final twinkle = (sin(elapsed * 1.5 + twinklePhase) + 1) / 2; // 0→1  // Only ~20% of particles twinkle at any given moment (threshold 0.8)  final twinkleBoost = twinkle > 0.80      ? (twinkle - 0.80) / 0.20 * 0.35  // up to +35% opacity boost      : 0.0;  final twinkleOpacity = (opacity + twinkleBoost).clamp(0.0, 1.0);  _particlePaint.color = (isBright ? bright : base)      .withValues(alpha: twinkleOpacity); }`

---

## TASK 17 — Thinking State: Typing Indicator Dots

## NOT in original MD. While AI is thinking, show 3 animated dots

## below the orb (like iMessage typing indicator) — gives the user

## clear feedback that processing is happening.

dart

`Widget _buildThinkingDots() {   if (_voiceState != VoiceState.thinking) return const SizedBox.shrink();   return AnimatedBuilder(    animation: _timeCtrl,    builder: (context, _) {      final t =`

Continuing exactly from where Task 17 was cut off:

text

      `final t = _elapsed;       // Each dot has a phase offset of 0.3s — classic staggered bounce      final d1 = (sin(t * 4.0 + 0.0) + 1) / 2;  // dot 1 phase      final d2 = (sin(t * 4.0 + 1.2) + 1) / 2;  // dot 2 phase (+0.3s)      final d3 = (sin(t * 4.0 + 2.4) + 1) / 2;  // dot 3 phase (+0.6s)       return Row(        mainAxisSize: MainAxisSize.min,        crossAxisAlignment: CrossAxisAlignment.center,        children: [          _buildThinkingDot(d1),          const SizedBox(width: 8),          _buildThinkingDot(d2),          const SizedBox(width: 8),          _buildThinkingDot(d3),        ],      );    },  ); } Widget _buildThinkingDot(double phase) {   // phase: 0.0→1.0  // At peak (1.0): full size, bright teal  // At trough (0.0): small, dim  final size   = 5.0 + phase * 4.0;        // 5px → 9px  final opacity = 0.25 + phase * 0.65;     // 25% → 90%  final yOffset = -phase * 5.0;            // bounces up by 5px at peak   return Transform.translate(    offset: Offset(0, yOffset),    child: Container(      width: size,      height: size,      decoration: BoxDecoration(        shape: BoxShape.circle,        color: const Color(0xFF00AACC).withValues(alpha: opacity),      ),    ),  ); }`

## 17b — Place Thinking Dots in Layout

Position the dots centered horizontally, just below the (now-contracted)  
orb and above the status label:

dart

`// In voice mode Stack layout: Positioned(   bottom: 168,  left: 0,  right: 0,  child: Column(    mainAxisSize: MainAxisSize.min,    children: [       // Thinking dots — crossfade in/out with waveform from Task 13      AnimatedSwitcher(        duration: const Duration(milliseconds: 400),        transitionBuilder: (child, anim) => FadeTransition(          opacity: anim,          child: SlideTransition(            position: Tween<Offset>(              begin: const Offset(0, 0.5),              end: Offset.zero,            ).animate(CurvedAnimation(              parent: anim as Animation<double>,              curve: Curves.easeOut,            )),            child: child,          ),        ),        child: switch (_voiceState) {          VoiceState.listening => KeyedSubtree(              key: const ValueKey('waveform'),              child: _buildMicWaveform(),            ),          VoiceState.thinking => KeyedSubtree(              key: const ValueKey('dots'),              child: _buildThinkingDots(),            ),          _ => const SizedBox(height: 28, key: ValueKey('empty')),        },      ),       const SizedBox(height: 10),       // Status label (Task 7)      AnimatedSwitcher(        duration: const Duration(milliseconds: 300),        child: Text(          _statusLabel,          key: ValueKey(_statusLabel),          style: TextStyle(            fontSize: 16,            fontWeight: FontWeight.w300,            color: Colors.white.withValues(alpha: 0.55),            letterSpacing: 0.3,          ),        ),      ),    ],  ), ),`

## 17c — Dots Entry Timing

The dots should only become visible after the orb has finished contracting  
(from Task 10b — `_thinkCtrl` reaches 1.0 after 650ms). Delay their  
appearance with a simple boolean:

dart

`// Add to State: bool _thinkingDotsVisible = false; // In _onStateChanged(), case VoiceState.thinking: case VoiceState.thinking:   _thinkCtrl.animateTo(1.0,      duration: const Duration(milliseconds: 650),      curve: Curves.easeInOut);  // Show dots only after orb has contracted  Future.delayed(const Duration(milliseconds: 500), () {    if (mounted && _voiceState == VoiceState.thinking) {      setState(() => _thinkingDotsVisible = true);    }  }); // Hide dots immediately when leaving thinking state: case VoiceState.speaking:   _thinkCtrl.animateTo(0.0, /* ... */);  setState(() => _thinkingDotsVisible = false); case VoiceState.idle:   _thinkCtrl.animateTo(0.0, /* ... */);  setState(() => _thinkingDotsVisible = false);`

Update the AnimatedSwitcher child condition from Task 17b:

dart

`child: switch (_voiceState) {   VoiceState.listening => KeyedSubtree(      key: const ValueKey('waveform'),      child: _buildMicWaveform(),    ),  VoiceState.thinking when _thinkingDotsVisible => KeyedSubtree(      key: const ValueKey('dots'),      child: _buildThinkingDots(),    ),  _ => const SizedBox(height: 28, key: ValueKey('empty')), },`

---

## TASK 18 — Response Text: Scroll Overflow Handling

## NOT in original MD. When AI gives a long response the text will

## overflow the top area. Currently no scroll handling exists.

## 18a — Scrollable Text Container

Replace the static `Positioned` text widget with a scrollable version:

dart

`// Replace existing Positioned text block with: Positioned(   top: 88,  left: 26,  right: 26,  // Bottom boundary stops above the bottom bar (leaves 200px clear)  bottom: 200,  child: _words.isEmpty      ? const SizedBox.shrink()      : FadeTransition(          opacity: _textFadeCtrl,          child: SingleChildScrollView(            // Auto-scrolls to bottom as new words stream in            controller: _responseScrollCtrl,            physics: const BouncingScrollPhysics(),            child: _buildStreamingText(),          ),        ), ),`

Add scroll controller:

dart

`// Add to State: final ScrollController _responseScrollCtrl = ScrollController(); // Auto-scroll to bottom each time a new word is revealed (Task 4a): void scheduleNext() {   // ... existing word timer logic ...  setState(() => _revealedWordCount++);   // Auto-scroll to show latest word  WidgetsBinding.instance.addPostFrameCallback((_) {    if (_responseScrollCtrl.hasClients) {      _responseScrollCtrl.animateTo(        _responseScrollCtrl.position.maxScrollExtent,        duration: const Duration(milliseconds: 120),        curve: Curves.easeOut,      );    }  });   scheduleNext(); } // Dispose: @override void dispose() {   _responseScrollCtrl.dispose();  // ... existing dispose calls  super.dispose(); }`

## 18b — Fade Mask on Text Container Bottom Edge

Add a gradient fade at the bottom of the text area so text disappears  
smoothly rather than hard-clipping at the boundary:

dart

`// Wrap the SingleChildScrollView with a ShaderMask: ShaderMask(   shaderCallback: (Rect bounds) {    return const LinearGradient(      begin: Alignment.topCenter,      end: Alignment.bottomCenter,      colors: [        Colors.white,   // fully visible at top        Colors.white,   // fully visible through most        Colors.transparent, // fades out at bottom edge      ],      stops: [0.0, 0.75, 1.0],    ).createShader(bounds);  },  blendMode: BlendMode.dstIn,  child: SingleChildScrollView(    controller: _responseScrollCtrl,    physics: const BouncingScrollPhysics(),    child: Padding(      // Extra bottom padding so last line isn't cut by the mask      padding: const EdgeInsets.only(bottom: 32),      child: _buildStreamingText(),    ),  ), ),`

---

## TASK 19 — Settings Icon Polish

## NOT in original MD. The gear icon top-right currently sits on its

## own with no visual context. Small enhancement: give it a subtle

## frosted dark pill background and hide it during speaking state.

dart

`// Replace existing settings icon Positioned widget: Positioned(   top: 0,  right: 0,  child: SafeArea(    child: AnimatedOpacity(      duration: const Duration(milliseconds: 400),      // Fade to near-invisible during speaking so it doesn't distract      opacity: _voiceState == VoiceState.speaking ? 0.15 : 0.75,      child: Padding(        padding: const EdgeInsets.only(top: 8, right: 16),        child: GestureDetector(          onTap: () { /* existing settings tap handler */ },          child: Container(            width: 36,            height: 36,            decoration: BoxDecoration(              color: Colors.white.withValues(alpha: 0.08),              borderRadius: BorderRadius.circular(10),              border: Border.all(                color: Colors.white.withValues(alpha: 0.10),                width: 0.8,              ),            ),            child: Icon(              Icons.settings_outlined,              size: 18,              color: Colors.white.withValues(alpha: 0.70),            ),          ),        ),      ),    ),  ), ),`

---

## TASK 20 — Full SpherePainter Final Signature Summary

## Reference: complete list of all parameters SpherePainter needs

## after all tasks above are implemented.

dart

`class SpherePainter extends CustomPainter {   // ── Existing ──────────────────────────────────────────────  final double      progress;          // 0.0→1.0 sphere rotation driver  final VoiceState  state;             // current voice state  final bool        dense;             // true = 300 particles (mini orb)   // ── Task 1: Amplitude ─────────────────────────────────────  final double      amplitude;         // 0.0→1.0 fake/real audio amplitude  final double      elapsed;           // seconds wall clock 0→60 looping   // ── Task 2: Organic Feel ──────────────────────────────────  final double      breathScale;       // 0.92→1.08 organic size oscillation  final double      stateBlend;        // 0.0=warm → 1.0=cool color blend   // ── Task 10: Thinking ─────────────────────────────────────  final double      thinkingContraction; // 0.0→1.0 inward radius pull   // ── Task 12: Speaking Beats ───────────────────────────────  final double      beatStrength;      // 0.0→1.0 syllable beat intensity   // ── Task 14/15: Entry/Exit ────────────────────────────────  final double      entryProgress;     // 0.0→1.0 particle materialization  final bool        isExiting;         // scatter particles on exit   // ── Task 16: Idle Tilt ────────────────────────────────────  final double      idleTiltX;         // 0.0→1.0 slow X-axis tilt   const SpherePainter({    required this.progress,    required this.state,    this.dense            = false,    this.amplitude        = 0.0,    this.elapsed          = 0.0,    this.breathScale      = 1.0,    this.stateBlend       = 0.0,    this.thinkingContraction = 0.0,    this.beatStrength     = 0.0,    this.entryProgress    = 1.0,    this.isExiting        = false,    this.idleTiltX        = 0.0,  });   @override  bool shouldRepaint(SpherePainter old) =>      old.progress          != progress          ||      old.state             != state             ||      old.amplitude         != amplitude         ||      old.elapsed           != elapsed           ||      old.breathScale       != breathScale       ||      old.stateBlend        != stateBlend        ||      old.thinkingContraction != thinkingContraction ||      old.beatStrength      != beatStrength      ||      old.entryProgress     != entryProgress     ||      old.isExiting         != isExiting         ||      old.idleTiltX         != idleTiltX; }`

---

## TASK 21 — Full AnimationController Summary

## Reference: complete list of all controllers the State widget needs.

dart

`// ── Existing (keep as-is) ───────────────────────────────── late AnimationController _sphereCtrl;    // 4s repeat — sphere rotation late AnimationController _pulseCtrl;     // 1.2s repeat reverse — speaking scale late AnimationController _textFadeCtrl;  // 450ms — text fade in late AnimationController _modeCtrl;      // 350ms — voice overlay fade // ── New (add these) ─────────────────────────────────────── late AnimationController _timeCtrl;      // 60s repeat — wall clock late AnimationController _breathCtrl;    // 3.2s repeat reverse — breath scale late AnimationController _stateTransitionCtrl; // 0→1 — warm/cool blend late AnimationController _thinkCtrl;     // 650ms — thinking contraction late AnimationController _orbEntryCtrl;  // 700ms — entry materialization`

## Init all in `initState()`:

dart

`@override void initState() {   super.initState();   // Existing:  _sphereCtrl = AnimationController(    vsync: this, duration: const Duration(seconds: 4))..repeat();  _pulseCtrl  = AnimationController(    vsync: this, duration: const Duration(milliseconds: 1200))    ..repeat(reverse: true);  _textFadeCtrl = AnimationController(    vsync: this, duration: const Duration(milliseconds: 450));  _modeCtrl = AnimationController(    vsync: this, duration: const Duration(milliseconds: 350));   // New:  _timeCtrl = AnimationController(    vsync: this, duration: const Duration(seconds: 60))..repeat();  _breathCtrl = AnimationController(    vsync: this, duration: const Duration(milliseconds: 3200))    ..repeat(reverse: true);  _stateTransitionCtrl = AnimationController(    vsync: this, duration: const Duration(milliseconds: 500));  _thinkCtrl = AnimationController(    vsync: this, duration: const Duration(milliseconds: 650));  _orbEntry`