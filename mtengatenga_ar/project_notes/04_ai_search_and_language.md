# AI, Search, and Language

## How AI Guide works

Main files:

- `lib/features/ai_guide/ai_guide_screen.dart`
- `lib/features/ai_guide/voice_chat_screen.dart`
- `lib/services/gemini_service.dart`

### Simple explanation

Think of the AI Guide like a smart museum storyteller.

- the user asks a question about an artifact
- the app sends the question and artifact context to `GeminiService`
- the AI returns a helpful explanation
- the response can be text or voice-style output depending on the mode

Inside `GeminiService`, there are different guide modes:

- text
- voice
- tour

It can also use cloud endpoints like:

- `/ai-chat`
- `/ai-chat-stream`

## How voice works

Voice-related files:

- `lib/services/openai_tts_service.dart`
- `lib/services/elevenlabs_tts_service.dart`
- `lib/services/kokoro_tts_service.dart`
- `lib/services/kokoro_model_manager.dart`

### Easy explanation

The app has more than one way to speak.

- some speech is cloud-based
- some speech can be on-device
- this gives the app backup choices for voice output

## How search works

Main files:

- `lib/features/search/search_screen.dart`
- `lib/services/search_service.dart`

### Search flow

1. user types a query
2. `SearchService` tries semantic search first
3. it can call the Supabase RPC function `match_artifacts`
4. if that is weak or fails, it falls back to text search
5. if needed, it can also do a local fallback search
6. tapping a result opens `ArtifactDetailsScreen`

This is smart because it tries the best search first, but still has backups.

## How translation and language work

Main file:

- `lib/services/translation_service.dart`

Profile screen:

- `lib/features/profile/profile_preferences_screen.dart`

### Easy explanation

`LanguageState` remembers the selected app language.
`TranslationService` translates text when the app language is not English.
The selected language is stored with `SharedPreferences`, so it stays after reopening the app.

## Easy interview answer

You can say:

`The AI Guide uses Gemini-based logic to answer questions about museum artifacts in text, voice, or tour mode. Search uses a layered strategy: semantic search first, then text fallback, then local fallback. The app also supports translation and persistent language settings so users can explore content in their preferred language.`
