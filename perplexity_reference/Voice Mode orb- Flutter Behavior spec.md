Here’s a Flutter-focused version of the same concept that you can drop into an `.md` file.

```markdown
# Voice Mode Orb — Flutter Behavior Spec

This document describes the **voice mode orb** in Flutter terms: how it looks, how it animates, and how its state changes based on who is “holding the mic” (user vs AI).

---

## 1. Core Implementation Concept

At a high level, the orb can be implemented as:

- A `StatefulWidget` with:
  - An `AnimationController` (or multiple) for size, color, and subtle motion.
  - A state enum, for example:
    ```dart
    enum VoiceOrbState { activation, listening, processing, waiting }
    ```
  - A `CustomPaint` or `AnimatedContainer` to draw/animate the circle.

- Real-time inputs:
  - `double userAmplitude` – normalized 0.0–1.0 from mic volume.
  - `bool isUserSpeaking`
  - `bool isAiSpeaking`

The widget reacts to these inputs and updates `VoiceOrbState` and animation targets accordingly.

---

## 2. State Machine Overview

The orb has four main states:

```dart
enum VoiceOrbState {
  activation,  // Just turned on
  listening,   // User is speaking
  processing,  // AI is “thinking / talking”
  waiting,     // Waiting for user
}
```

A typical flow:

1. User taps **voice** button → `activation`
2. Mic opens, user starts speaking → `listening`
3. User stops, AI starts responding → `processing`
4. AI finishes, waiting for next user input → `waiting`

Transitions are driven by voice events (speech start/stop, TTS start/stop) and handled in `setState`.

---

## 3. Activation State (User Just Turned On Voice Mode)

**Behavior (Flutter terms):**

- On tap, set state:
  ```dart
  _state = VoiceOrbState.activation;
  _sizeController.forward(from: 0.0);
  _colorController.animateTo(activationColorValue);
  ```
- Use:
  - `AnimationController` for scale (`Tween<double>(begin: 0.8, end: 1.0)`).
  - A subtle ease curve: `Curves.easeOut`.

**Visual result:**

- Medium-sized orb, centered.
- Soft neutral/light color (e.g. pale blue).
- Gentle “breathe in” pulse indicating voice mode is active.

---

## 4. Listening State (User is Speaking)

When the user speaks, the orb should feel “alive” and reactive.

**State entry:**

```dart
void onUserStartSpeaking(double amplitude) {
  setState(() {
    _state = VoiceOrbState.listening;
  });
  _updateAmplitude(amplitude);
}
```

**Size animation:**

- Bind radius/scale to `userAmplitude`:
  ```dart
  final double minRadius = 40.0;
  final double maxRadius = 80.0;
  final double radius =
      lerpDouble(minRadius, maxRadius, userAmplitude.clamp(0.0, 1.0))!;
  ```
- You can smooth it with an `AnimationController`:
  ```dart
  _amplitudeController.animateTo(
    userAmplitude,
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOut,
  );
  ```

**Color behavior:**

- Warm, “sun-like” tones to represent user energy (e.g. yellow/orange gradient).
- You can drive color via a `ColorTween`:
  ```dart
  final colorTween = ColorTween(
    begin: Colors.yellow.shade400,
    end: Colors.orange.shade600,
  );
  final currentColor = colorTween.evaluate(_colorController);
  ```

**Rendering:**

- Use `CustomPaint` to draw a circle that grows/shrinks with amplitude.
- Optionally add multiple layers (inner core + outer glow) using a `Stack` of `CustomPaint` widgets for richer motion.

---

## 5. Processing State (AI is Talking / Thinking)

When the user stops speaking and the AI responds, the orb should visually switch to “AI mode”.

**State entry:**

```dart
void onAiStartSpeaking() {
  setState(() {
    _state = VoiceOrbState.processing;
  });
  _sizeController.animateTo(0.7, curve: Curves.easeOut);
  _colorController.animateTo(processingColorValue);
}
```

**Size & motion:**

- Orb shrinks slightly to a compact, focused size.
- Pulse frequency slows:
  - You can use a long-running `AnimationController` (e.g. 6–10 seconds loop) and map its value to small breathing changes in radius.

**Color behavior:**

- Shift to cooler **blue** tones to indicate AI activity:
  ```dart
  final colorTween = ColorTween(
    begin: Colors.blue.shade400,
    end: Colors.blue.shade700,
  );
  ```

**Animation feel:**

- Less amplitude-driven, more stable and calm.
- The idea: “system thinking/responding” rather than “user talking”.

---

## 6. Waiting State (Ready for User to Speak Again)

After AI finishes, the orb indicates that the floor is back to the user.

**State entry:**

```dart
void onAiFinished() {
  setState(() {
    _state = VoiceOrbState.waiting;
  });
  _sizeController.animateTo(0.5, curve: Curves.easeOut);
  _colorController.animateTo(waitingColorValue);
}
```

**Positioning:**

- Orb can move to the bottom of the screen (near mic button area) using an animated layout:
  - `AnimatedAlign`, `AnimatedPositioned`, or a `SlideTransition`.

**Visual properties:**

- Small, non-intrusive orb.
- Warm **sun-like** color (yellow/orange), same palette as listening but more subtle.
- Low-intensity idle pulse that signals:
  - Mic is open.
  - User can start speaking anytime.

---

## 7. Widget Structure Example (High Level)

```dart
class VoiceOrb extends StatefulWidget {
  final double userAmplitude;
  final bool isUserSpeaking;
  final bool isAiSpeaking;

  const VoiceOrb({
    super.key,
    required this.userAmplitude,
    required this.isUserSpeaking,
    required this.isAiSpeaking,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _sizeController;
  late AnimationController _colorController;
  VoiceOrbState _state = VoiceOrbState.activation;

  @override
  void initState() {
    super.initState();
    _sizeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: 0.5,
      upperBound: 1.0,
    );
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isUserSpeaking) {
      _toListening();
    } else if (widget.isAiSpeaking) {
      _toProcessing();
    } else {
      _toWaiting();
    }
  }

  void _toListening() { /* set _state + animate size & color */ }
  void _toProcessing() { /* set _state + animate size & color */ }
  void _toWaiting() { /* set _state + animate size & color */ }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder or AnimatedContainer + CustomPaint for orb
    return AnimatedBuilder(
      animation: Listenable.merge([_sizeController, _colorController]),
      builder: (context, child) {
        // Compute radius, color based on _state and controllers
        return CustomPaint(
          painter: _OrbPainter(
            state: _state,
            sizeFactor: _sizeController.value,
            colorFactor: _colorController.value,
            amplitude: widget.userAmplitude,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _colorController.dispose();
    super.dispose();
  }
}
```

---

## 8. Summary in Flutter Terms

- **States**: Implemented via `enum` + `setState`, driven by voice events.
- **Size changes**: `AnimationController` + amplitude mapping for listening, steady values for processing/waiting.
- **Colors**:
  - Activation: neutral/light.
  - Listening: warm/sun-like (user speaking).
  - Processing: calm blue (AI speaking).
  - Waiting: small warm orb at bottom (user can talk).
- **Rendering**: `CustomPaint` or layered widgets in a `Stack` for glow, with `AnimatedAlign`/`AnimatedPositioned` to move the orb in the layout.

This way the behavior you described (big when user talks, shrinking and turning blue when AI responds, small sun-colored orb at the bottom when it’s the user’s turn again) is explicitly modeled in Flutter’s animation and state system.
```
