# Perplexity Voice Mode — Reference Screenshots

Paste screenshots into the matching subfolder, then tell Claude to analyze them.

---

## Folder Structure

```
perplexity_reference/
├── idle/          → App open, voice mode active, not doing anything — resting orb state
├── listening/     → Mic is on, user is speaking — orb reacting to voice input
├── thinking/      → User finished speaking, AI is processing — loading/thinking state
├── speaking/      → AI is responding, reading out answer — orb + text state
└── transitions/   → Any in-between or mid-animation screenshots if you can catch them
```

---

## What to Capture Per State

| State        | Look for                                                                 |
|--------------|--------------------------------------------------------------------------|
| `idle`       | Orb color, size, glow, subtle animation, background, bottom bar layout  |
| `listening`  | How orb changes shape/color, pulse rings, waveform, mic button state    |
| `thinking`   | Contraction, spinner or dots, color shift, any text shown               |
| `speaking`   | Orb position, text layout, scroll behavior, fade effects, button layout |
| `transitions`| Any blurring, scaling, morphing caught mid-state                        |

---

## How to Use

Once you've added images to a folder, tell Claude:
> "Analyze the [state] screenshots in perplexity_reference/[folder]"

Claude will read every image, note specific details (colors, sizes, positioning, timing cues),
and map them to changes needed in `ai_guide_screen.dart`.
