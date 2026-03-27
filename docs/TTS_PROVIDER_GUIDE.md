# TTS Provider Guide — Mtengatenga Museum Voice Mode

All four TTS providers are **already implemented and wired in**. To switch providers, set `TTS_PROVIDER` in `mtengatenga_ar/.env` and add the corresponding API key. No code changes needed.

---

## Quick Start

1. Pick a provider from the table below
2. Get the API key
3. Set `TTS_PROVIDER=<provider>` and the API key in `mtengatenga_ar/.env`
4. `flutter run`

| Provider | `.env` value | Free tier | Latency | Quality |
|---|---|---|---|---|
| Google Cloud TTS | `google_cloud` | 1M chars/month (Neural2) | ~300ms | High |
| Gemini TTS | `gemini` | 20 req/min (free tier) | ~800ms | Good |
| OpenAI TTS | `openai` | None (paid only) | ~500ms | Very High |
| ElevenLabs | `elevenlabs` | 10K chars/month | ~400ms | Excellent |

---

## Provider Details

### 1. Google Cloud TTS (Recommended for free tier)

**Service file:** `lib/services/google_cloud_tts_service.dart`

**Setup:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Enable **Cloud Text-to-Speech API** on your project
3. Create an API key (or use your existing Gemini key if unrestricted)

**`.env` config:**
```
TTS_PROVIDER=google_cloud
GOOGLE_CLOUD_TTS_KEY=your_key_here
GOOGLE_CLOUD_TTS_VOICE=en-US-Neural2-F
GOOGLE_CLOUD_TTS_LANGUAGE=en-US
```

If `GOOGLE_CLOUD_TTS_KEY` is empty, the service falls back to `GEMINI_API_KEY`.

**Voice options (all free tier — Neural2):**
| Voice | Description |
|---|---|
| `en-US-Neural2-F` | Warm female (default) |
| `en-US-Neural2-C` | Female, slightly different tone |
| `en-US-Neural2-H` | Female, softer |
| `en-US-Neural2-D` | Male, neutral |
| `en-US-Neural2-A` | Male, deep |
| `en-US-Neural2-J` | Male, warm |
| `en-US-Studio-O` | Premium female (free up to 1M chars/month) |
| `en-US-Studio-Q` | Premium male |

**How it works:**
- `POST https://texttospeech.googleapis.com/v1/text:synthesize?key=API_KEY`
- Body: `{ input: {text}, voice: {languageCode, name}, audioConfig: {audioEncoding: LINEAR16, sampleRateHertz: 24000} }`
- Returns JSON with `audioContent` as base64-encoded PCM
- Service decodes base64 → wraps PCM as WAV → returns `GoogleCloudSpeechClip`

**Free tier limits:**
- Standard voices: 4M chars/month
- WaveNet voices: 1M chars/month
- Neural2 voices: 1M chars/month
- Studio voices: 1M chars/month

---

### 2. Gemini TTS (Built-in, uses same key as text generation)

**Service file:** `lib/services/gemini_tts_service.dart`

**Setup:**
1. Get a Gemini API key from [aistudio.google.com](https://aistudio.google.com)
2. That's it — the same `GEMINI_API_KEY` used for text generation works for TTS

**`.env` config:**
```
TTS_PROVIDER=gemini
GEMINI_API_KEY=your_key_here
GEMINI_TTS_MODEL=gemini-2.5-flash-preview-tts
GEMINI_TTS_VOICE=Sulafat
```

**Voice options:**
| Voice | Description |
|---|---|
| `Sulafat` | Warm female (default) |
| `Zephyr` | Bright female |
| `Puck` | Playful male |
| `Charon` | Deep male |
| `Kore` | Calm female |

**How it works:**
- `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Header: `x-goog-api-key: API_KEY`
- Body uses `responseModalities: ['AUDIO']` with `speechConfig.voiceConfig`
- Returns JSON → extract `candidates[0].content.parts[0].inlineData.data` (base64 PCM)
- Service decodes base64 → wraps PCM as WAV → returns `GeminiSpeechClip`
- Tries model candidates in order: configured → `gemini-2.5-flash-preview-tts` → `gemini-2.5-flash-lite-preview-tts`

**Free tier limits:**
- 20 requests/minute
- Shared with text generation quota

---

### 3. OpenAI TTS (Best quality, paid only)

**Service file:** `lib/services/openai_tts_service.dart`

**Setup:**
1. Go to [platform.openai.com](https://platform.openai.com)
2. Add billing credits (minimum $5)
3. Create an API key

**`.env` config:**
```
TTS_PROVIDER=openai
OPENAI_API_KEY=sk-proj-...
OPENAI_TTS_VOICE=nova
```

**Voice options:**
| Voice | Description |
|---|---|
| `nova` | Warm female (default, recommended) |
| `shimmer` | Soft female |
| `alloy` | Neutral, balanced |
| `echo` | Male, warm |
| `onyx` | Male, deep |
| `fable` | British-accented |

**How it works:**
- `POST https://api.openai.com/v1/audio/speech`
- Header: `Authorization: Bearer API_KEY`
- Body: `{ model: "tts-1-hd", input: text, voice: "nova", response_format: "wav" }`
- Returns raw WAV bytes directly (no base64, no wrapping needed)
- Service reads response bytes → parses WAV header for duration → returns `SpeechClip`

**Pricing:**
- `tts-1-hd`: $0.030 per 1K characters
- No free tier

---

### 4. ElevenLabs (Most natural, limited free tier)

**Service file:** `lib/services/elevenlabs_tts_service.dart`

**Setup:**
1. Sign up at [elevenlabs.io](https://elevenlabs.io)
2. Go to Profile → API Key
3. Copy your API key

**`.env` config:**
```
TTS_PROVIDER=elevenlabs
ELEVENLABS_API_KEY=your_key_here
ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM
ELEVENLABS_MODEL=eleven_multilingual_v2
```

**Voice options (voice IDs):**
| Voice | ID | Description |
|---|---|---|
| Rachel | `21m00Tcm4TlvDq8ikWAM` | Warm female narrator (default) |
| Domi | `AZnzlk1XvdvUeBnXmlld` | Confident female |
| Bella | `EXAVITQu4vr4xnSDxMaL` | Soft female |
| Antoni | `ErXwobaYiN019PkySvjV` | Warm male |
| Josh | `TxGEqnHWrfWFTfGW9XjX` | Deep male |
| Arnold | `VR6AewLTigWG4xSOukaG` | Strong male |

You can also create custom voices at [elevenlabs.io/voice-lab](https://elevenlabs.io/voice-lab) and use the resulting voice ID.

**How it works:**
- `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=pcm_24000`
- Header: `xi-api-key: API_KEY`
- Body: `{ text, model_id, voice_settings: { stability, similarity_boost, style, use_speaker_boost } }`
- Returns raw PCM bytes (signed 16-bit LE mono @ 24 kHz)
- Service wraps PCM as WAV → returns `ElevenLabsSpeechClip`

**Free tier limits:**
- 10,000 characters/month
- 3 custom voices

---

## Architecture

### Routing (`ai_guide_screen.dart`)

The `_synthesizeSpeech(String text)` method routes to the active provider:

```
TTS_PROVIDER env var
    ├── "google_cloud" → GoogleCloudTtsService
    ├── "openai"       → OpenAiTtsService
    ├── "elevenlabs"   → ElevenLabsTtsService
    └── "gemini"       → GeminiTtsService (default)
```

If `TTS_PROVIDER` is not set, auto-detection checks API keys in order:
`ELEVENLABS_API_KEY` → `OPENAI_API_KEY` → `GOOGLE_CLOUD_TTS_KEY` → falls back to `gemini`.

### Fallback chain

If the selected TTS provider fails mid-stream:
1. Failed chunk text is accumulated in `_unsynthesizedText`
2. Successfully synthesized chunks continue playing
3. After last queued chunk finishes, device TTS (`flutter_tts`) speaks the remainder
4. Session settles to waiting state

### Service interface

All four services follow the same pattern:
```dart
Future<XxxSpeechClip> synthesizeSpeech(String text)
// Returns: { wavBytes: Uint8List, duration: Duration }
```

All output 24 kHz, 16-bit mono WAV. The screen doesn't care which provider produced it.

### Files

| File | Purpose |
|---|---|
| `lib/services/gemini_tts_service.dart` | Gemini TTS via REST API |
| `lib/services/google_cloud_tts_service.dart` | Google Cloud Text-to-Speech |
| `lib/services/openai_tts_service.dart` | OpenAI TTS (tts-1-hd) |
| `lib/services/elevenlabs_tts_service.dart` | ElevenLabs TTS |
| `lib/features/ai_guide/ai_guide_screen.dart` | Voice mode UI + TTS routing |
| `mtengatenga_ar/.env` | API keys and provider config |
| `mtengatenga_ar/.env.example` | Template with all config options |

---

## Full `.env` Reference

```bash
# ── Supabase ──────────────────────────────────────────────
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key

# ── Gemini (text generation + optional TTS) ───────────────
GEMINI_API_KEY=your_gemini_key
GEMINI_MODEL=gemini-2.5-flash
GEMINI_TTS_MODEL=gemini-2.5-flash-preview-tts
GEMINI_TTS_VOICE=Sulafat

# ── Google Cloud TTS ──────────────────────────────────────
GOOGLE_CLOUD_TTS_KEY=              # leave empty to reuse GEMINI_API_KEY
GOOGLE_CLOUD_TTS_VOICE=en-US-Neural2-F
GOOGLE_CLOUD_TTS_LANGUAGE=en-US

# ── OpenAI TTS ────────────────────────────────────────────
OPENAI_API_KEY=sk-proj-...
OPENAI_TTS_VOICE=nova

# ── ElevenLabs TTS ────────────────────────────────────────
ELEVENLABS_API_KEY=
ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM
ELEVENLABS_MODEL=eleven_multilingual_v2

# ── TTS Provider Selection ────────────────────────────────
# Options: gemini | google_cloud | openai | elevenlabs
# If empty, auto-detects from which API keys are present.
TTS_PROVIDER=
```

---

## Adding a New TTS Provider

To add a fifth provider:

1. Create `lib/services/new_provider_tts_service.dart` following this pattern:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NewProviderSpeechClip {
  final Uint8List wavBytes;
  final Duration duration;
  const NewProviderSpeechClip({required this.wavBytes, required this.duration});
}

class NewProviderTtsService {
  static const int _maxRetries = 2;
  static const int _sampleRate = 24000;

  Future<NewProviderSpeechClip> synthesizeSpeech(String text) async {
    final apiKey = dotenv.env['NEW_PROVIDER_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) throw StateError('Missing NEW_PROVIDER_API_KEY');

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final client = HttpClient();
      try {
        // 1. Build and send the HTTP request
        final request = await client.postUrl(Uri.parse('https://api.newprovider.com/tts'));
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $apiKey');
        request.add(utf8.encode(jsonEncode({'text': text, /* provider-specific fields */ })));

        final response = await request.close();

        // 2. Handle rate limits with retry
        if (response.statusCode == 429) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
        }

        // 3. Extract audio bytes (provider-specific)
        // Option A: Response is raw audio bytes (like OpenAI)
        //   final wavBytes = await _collectBytes(response);
        // Option B: Response is JSON with base64 audio (like Google Cloud)
        //   final body = await utf8.decoder.bind(response).join();
        //   final pcmBytes = base64Decode(jsonDecode(body)['audio']);
        //   final wavBytes = _wrapPcmAsWav(pcmBytes);

        // 4. Calculate duration and return
        final durationMicros = (pcmBytes.length * 1000000) ~/ (_sampleRate * 2);
        return NewProviderSpeechClip(
          wavBytes: wavBytes,
          duration: Duration(microseconds: durationMicros),
        );
      } finally {
        client.close(force: true);
      }
    }
    throw StateError('Failed');
  }

  // Copy _wrapPcmAsWav from any existing service if the provider returns raw PCM.
}
```

2. Wire it in `ai_guide_screen.dart`:
   - Add import: `import '../../services/new_provider_tts_service.dart';`
   - Add field: `final _newProviderTtsService = NewProviderTtsService();`
   - Add case in `_ttsProvider` getter (auto-detect by key)
   - Add case in `_synthesizeSpeech` switch

3. Add env vars to `.env` and `.env.example`:
   ```
   NEW_PROVIDER_API_KEY=
   TTS_PROVIDER=new_provider
   ```
