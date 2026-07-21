# Voice Mode — Project Context for UI/UX Enhancement

This document gives you full context of a Flutter museum app's AI Guide voice mode so you can advise on how to enhance the animations and UX to match the quality of the Perplexity mobile voice chat experience.

---

## Project Overview

**App:** Mtengatenga — a museum companion app for a Malawian museum
**Platform:** Flutter (Android primary, ARCore AR feature)
**Design language:** Warm terracotta / earth tones (`#C05621` primary orange, `#F9F6F1` background)
**AI Guide feature:** A conversational AI assistant that tells visitors about artifacts. Has two modes — a text chat mode and a full-screen voice mode.

---

## File Location

```
mtengatenga_ar/lib/features/ai_guide/ai_guide_screen.dart
```

This is one self-contained file (~600 lines). No external animation packages — pure Flutter `AnimationController` + `CustomPainter`.

---

## Current Architecture

### Mode State Machine

```dart
enum _AiMode { text, voice }       // top-level screen mode
enum _VoiceState { idle, listening, thinking, speaking }  // voice sub-states
```

The screen has two layers stacked:
- **Text mode** (always underneath) — light-themed chat UI with suggestion chips and a dark composer bar
- **Voice mode** — fades in as a full-screen overlay on top when user taps the orange orb button in the composer

### Voice Mode Entry / Exit

```dart
void _enterVoice() {
  // Sets mode to voice, triggers fade-in animation (_modeCtrl.forward)
}

void _exitVoice() {
  // Reverses fade, then sets mode back to text after animation completes
}
```

### Voice State Transitions (Demo Flow — no real STT/TTS yet)

```dart
Future<void> _runDemoFlow() async {
  // idle → listening (tap orb)
  await Future.delayed(2s);
  // listening → thinking
  await Future.delayed(1.1s);
  // thinking → speaking (sets display text)
  await Future.delayed(7s);
  // speaking → idle (clears text)
}
```

**When real STT/TTS is wired:** replace `_runDemoFlow()` with `speech_to_text` recognition → API call → `flutter_tts` playback.

---

## The Particle Sphere Painter

The visual centrepiece. A `CustomPainter` that draws 800 particles (300 when dense/small) arranged on a sphere using spherical coordinates, rotating around the vertical Y-axis.

### Full Painter Code

```dart
class _SpherePainter extends CustomPainter {
  final double progress;   // 0.0–1.0, drives rotation (from AnimationController repeating over 4s)
  final _VoiceState state; // changes particle color palette
  final bool dense;        // true = 300 particles (used for the small bottom-bar orb)

  const _SpherePainter({
    required this.progress,
    required this.state,
    this.dense = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);           // fixed seed = same particle layout every frame
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;
    final count = dense ? 300 : 800;

    final isCool = state == _VoiceState.listening || state == _VoiceState.thinking;

    // Warm palette (idle / speaking) — app primary orange
    const sphereWarm = Color(0xFFC05621);
    const sphereWarmBright = Color(0xFFFFCB8A);
    // Cool palette (listening / thinking) — teal/cyan
    const sphereCool = Color(0xFF00AACC);
    const sphereCoolBright = Color(0xFF88EEFF);

    final base = isCool ? sphereCool : sphereWarm;
    final bright = isCool ? sphereCoolBright : sphereWarmBright;

    // Rotation speed around the vertical Y-axis
    final rotY = progress * 2 * pi * 0.35;

    for (int i = 0; i < count; i++) {
      final theta = rng.nextDouble() * 2 * pi; // azimuthal (longitude)
      final phi = acos(2 * rng.nextDouble() - 1); // polar (latitude)

      // 3D position before rotation
      final x0 = radius * sin(phi) * cos(theta);
      final y0 = radius * cos(phi);
      final z0 = radius * sin(phi) * sin(theta);

      // Rotate around Y axis
      final x = cx + x0 * cos(rotY) + z0 * sin(rotY);
      final y = cy + y0;
      final z = -x0 * sin(rotY) + z0 * cos(rotY);

      // Depth-based size & opacity
      final depth = (z / radius + 1) / 2; // 0 = back, 1 = front
      final dotSize = (dense ? 1.2 : 1.8) * (0.3 + depth * 0.9);
      final opacity = (0.15 + depth * 0.85).clamp(0.0, 1.0);

      final isBright = rng.nextDouble() > 0.85; // ~15% bright particles
      final color = (isBright ? bright : base).withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), dotSize, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.progress != progress || old.state != state;
}
```

### Animation Controllers in Use

| Controller | Duration | Purpose |
|---|---|---|
| `_sphereCtrl` | 4 seconds, repeat | Drives `progress` → sphere rotation |
| `_pulseCtrl` | 1.2 seconds, repeat reverse | Scale pulse 0.95→1.05 when `speaking` |
| `_textFadeCtrl` | 450ms, forward | Fades in AI response text |
| `_modeCtrl` | 350ms | Fades voice overlay in/out over text mode |

### Sphere Size / Position Transitions

```dart
// Large sphere centered → shrinks and moves to bottom when AI response text is showing
final size = hasText ? 66.0 : 230.0;
final align = hasText ? Alignment.bottomCenter : Alignment.center;
final pad = hasText ? EdgeInsets.only(bottom: 112) : EdgeInsets.zero;

// AnimatedAlign handles the transition (550ms, easeInOut)
```

---

## Background Gradient

```dart
// Warm (idle / speaking state)
const warmBg = Color(0xFF3A1F00);

// Cool (listening / thinking state)
const coolBg = Color(0xFF001A26);

// RadialGradient from bottomCenter, radius 1.3, fades to black
// AnimatedContainer with 700ms transition between warm/cool
```

---

## Voice Mode Layout Structure

```
Scaffold (black background)
├── Stack
│   ├── AnimatedContainer  ← radial gradient bg (warm/cool)
│   ├── AnimatedAlign      ← particle sphere (large/center OR small/bottom)
│   ├── Positioned (top 88, left/right 26, bottom 180)
│   │   └── FadeTransition ← AI response text (29px, weight 300, #CCCCCC)
│   ├── Positioned (top 0)
│   │   └── SafeArea row (settings icon right)
│   └── Positioned (bottom 0)
│       └── SafeArea column
│           ├── AnimatedOpacity text ("Say something..." / "Listening..." / "Thinking...")
│           └── Row: [X close btn] [72px tap-orb] [mic/keyboard btn]
```

---

## Bottom Bar Orb (Small)

The tappable orb in the bottom bar is a second instance of `_SpherePainter` at 72×72 with `dense: true` (300 particles). Tapping it cycles: `idle → listening → (demo flow) → thinking → speaking → idle`. Tapping during any active state cancels back to idle.

---

## What Is Working

- ✅ Sphere rotates correctly (Y-axis rotation, faces screen, not tilted)
- ✅ Color shifts warm↔cool based on `_VoiceState`
- ✅ Sphere transitions large/centered ↔ small/bottom when response text appears
- ✅ Background gradient animates between warm amber and cool teal
- ✅ Response text fades in
- ✅ Pulse scale animation during `speaking` state
- ✅ "Say something..." / "Listening..." / "Thinking..." label animates opacity
- ✅ Voice mode slides over text mode via fade, X button exits back

---

## What Needs Enhancement (Goal of This Document)

The current implementation has all the correct bones but the animations lack the **organic, fluid, alive quality** of the Perplexity voice orb. Specifically:

### 1. Sphere Energy / Breathing
Perplexity's sphere feels alive — the particles subtly breathe, cluster, and expand. Currently the sphere just rotates uniformly at a constant speed. Need:
- Variable rotation speed (slower at idle, faster/irregular when listening)
- Organic "breathing" scale — gentle size oscillation even at idle
- Particles at the equator should feel denser / more active

### 2. Listening State Animation
When Perplexity enters listening mode, the sphere visually reacts to incoming sound (amplitude). Currently we just swap the color palette. Need:
- Noise/turbulence displacement on particle positions (Perlin-like)
- Particles pulsing outward from center in waves
- Rotation accelerates slightly

### 3. Thinking State Animation
Perplexity's sphere in thinking state has a tighter, more contracted appearance — like the energy is being focused inward. Currently only the color changes. Need:
- Particles contract toward a smaller radius
- Slower, more deliberate rotation
- Maybe a spiraling / wormhole effect toward center

### 4. Speaking State Animation
When the AI speaks, Perplexity's orb has a visible "talking" rhythm — the surface undulates in sync with TTS output amplitude. Currently only a subtle 0.95→1.05 scale pulse exists. Need:
- Surface displacement mapped to audio amplitude (or faked with a sine wave)
- Particles push outward on "beats"
- Brighter flash of particles on stressed syllables

### 5. Particle Depth / Density Feel
The current uniform random distribution feels flat. Perplexity's sphere has:
- Higher particle density near the equator
- A glowing core (soft inner glow through particles)
- Slight haze / blur on back-facing particles (currently just opacity)

### 6. State Transition Animations
Currently state changes are instant (just color). Need:
- Smooth morphing between particle configurations across states
- Easing curves that feel physical (e.g., spring-like snap into listening)

### 7. Response Text
Perplexity streams text word-by-word with the last word appearing bold/bright. Currently the full text fades in at once. Need:
- Word-by-word reveal with a slight delay between words
- Last rendered word slightly brighter/bolder (as if being spoken right now)

---

## Constraints

- **No external packages preferred** — keep it pure Flutter `CustomPainter` + `AnimationController`
- If a package is genuinely needed (e.g., `simple_animations`, `rive`), flag it
- Must stay performant on mid-range Android (Tecno/Infinix level) — avoid per-frame allocation
- Fixed `Random(42)` seed is intentional (consistent particle layout); only `progress` drives movement
- STT/TTS not yet integrated — all enhancements should work with the demo flow and be pluggable for real audio amplitude later

---

## Key Files for Reference

```
mtengatenga_ar/lib/features/ai_guide/ai_guide_screen.dart  ← full voice mode implementation
mtengatenga_ar/lib/theme/app_tokens.dart                   ← AppColors, AppSpacing, AppRadius
mtengatenga_ar/lib/features/ai_guide/voice_chat_screen.dart ← original reference/prototype (not used in production)
```

---

## Ask for Perplexity

Given the full context above, advise on:

1. **Specific Flutter `CustomPainter` techniques** to make the sphere feel organic and alive (breathing, turbulence, density variation)
2. **How to animate state transitions** smoothly (idle → listening → thinking → speaking) with distinct visual personalities per state
3. **Word-by-word text streaming** implementation in Flutter with the "last word highlighted" effect
4. **Faking audio amplitude** in the demo flow using sine waves so the sphere reacts as if it were hearing real audio — ready to swap in real amplitude data later
5. **Performance tips** for keeping 800-particle `CustomPainter` smooth at 60fps on mid-range Android
