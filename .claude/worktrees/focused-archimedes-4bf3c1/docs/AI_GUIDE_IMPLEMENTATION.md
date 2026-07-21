# AI Guide Implementation Plan
> For Claude Code — Read this fully before making any changes.

---

## Current State (What Already Exists)

The AI guide feature is **UI-complete but uses mock data**. Here is exactly what exists:

### Existing Files
- `lib/features/ai_guide/ai_guide_screen.dart` — Full UI with text chat + voice mode + tour banner
- `lib/features/ai_guide/voice_chat_screen.dart` — Separate voice chat screen
- `lib/models/artifact.dart` — Artifact model with fields: id, name, description, model3dUrl, qrCode, category, period
- `lib/services/supabase_service.dart` — SupabaseService with `getArtifact(String qrCode)` method
- `lib/features/scan/scan_screen.dart` — QR scanner that navigates to artifact after scan
- `lib/features/artifact/artifact_details_screen.dart` — Artifact detail screen

### Current Mock Data in ai_guide_screen.dart
The screen uses a `_Mock` class with hardcoded `suggestions`, `responses`, and `voiceResponse` strings. These must be replaced with real Gemini API calls while keeping the exact same UI intact.

### Existing Dependencies (pubspec.yaml)
```yaml
supabase_flutter: ^2.0.0
flutter_dotenv: ^5.1.0
mobile_scanner: ^5.0.0
arcore_flutter_plugin: ^0.1.0
model_viewer_plus: ^1.8.1
shared_preferences: ^2.2.2
connectivity_plus: ^5.0.2
brick_offline_first_with_supabase: ^2.1.0
```

---

## Goal

Connect the existing `AiGuideScreen` to **real Gemini AI** so users get actual intelligent responses about Mtengatenga Museum artifacts. Also implement a real **Guided Tour** system backed by Supabase.

Two features to build:
1. **Artifact Chat** — AI answers questions grounded in specific artifact context from Supabase
2. **Guided Tour** — AI leads visitor through ordered museum stops with real narration

---

## Step 1: Supabase Database Setup (Use Supabase MCP)

> Claude Code has Supabase MCP connected. Use it to run these SQL migrations directly.

### 1a. Add `ai_context` column to existing `artifacts` table

```sql
ALTER TABLE artifacts 
ADD COLUMN IF NOT EXISTS ai_context TEXT;

COMMENT ON COLUMN artifacts.ai_context IS 
'Rich cultural and historical context used to ground the AI guide responses for this artifact.';
```

### 1b. Create `guided_tours` table

```sql
CREATE TABLE IF NOT EXISTS guided_tours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  duration_minutes INTEGER DEFAULT 30,
  difficulty TEXT DEFAULT 'easy' CHECK (difficulty IN ('easy', 'moderate', 'detailed')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE guided_tours IS 'Guided tour configurations for the museum AI guide.';
```

### 1c. Create `tour_stops` table

```sql
CREATE TABLE IF NOT EXISTS tour_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tour_id UUID NOT NULL REFERENCES guided_tours(id) ON DELETE CASCADE,
  artifact_id TEXT NOT NULL,
  stop_order INTEGER NOT NULL,
  narration TEXT NOT NULL,
  transition_hint TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tour_stops_tour_id ON tour_stops(tour_id);
CREATE INDEX IF NOT EXISTS idx_tour_stops_order ON tour_stops(tour_id, stop_order);

COMMENT ON TABLE tour_stops IS 'Ordered stops in a guided tour, each linked to an artifact.';
```

### 1d. Enable Row Level Security (RLS)

```sql
ALTER TABLE guided_tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE tour_stops ENABLE ROW LEVEL SECURITY;

-- Public read access (visitors can read tours)
CREATE POLICY "Public read guided_tours" ON guided_tours
  FOR SELECT USING (true);

CREATE POLICY "Public read tour_stops" ON tour_stops
  FOR SELECT USING (true);
```

### 1e. Seed one sample tour for testing

```sql
-- Insert a sample tour
WITH tour AS (
  INSERT INTO guided_tours (name, description, duration_minutes, difficulty)
  VALUES (
    'Cultural Heritage Tour',
    'Explore the rich cultural heritage of Malawi through key artifacts spanning 300 years of Chewa tradition.',
    45,
    'easy'
  )
  RETURNING id
),
-- Insert stops (replace artifact_id values with real qr_codes from your artifacts table)
stops AS (
  SELECT id AS tour_id FROM tour
)
INSERT INTO tour_stops (tour_id, artifact_id, stop_order, narration, transition_hint)
SELECT 
  stops.tour_id,
  artifact_id,
  stop_order,
  narration,
  transition_hint
FROM stops,
(VALUES
  ('CHW001', 1, 
   'Welcome to Mtengatenga Cultural Museum. You are standing before the Gule Wamkulu mask, one of the most sacred objects in Chewa culture. This mask was worn by initiated Nyau society members during funeral ceremonies to guide the departed into the ancestral realm.',
   'Make your way to the Hall of Ancestors on your left for the next exhibit.'),
  ('POT002', 2,
   'This ceremonial pottery vessel was used during initiation ceremonies. Notice the intricate geometric patterns — each symbol carries specific meaning within Chewa cosmology.',
   'Continue to the Instruments Gallery at the far end of this hall.')
) AS v(artifact_id, stop_order, narration, transition_hint);
```

### 1f. Update artifacts with AI context (sample)

```sql
-- Run this for each artifact — update with real artifact IDs from your table
UPDATE artifacts 
SET ai_context = 'The Gule Wamkulu mask is a sacred object of the Chewa people of Malawi. It belongs to the Nyau secret society, a fraternity of initiated men who wear these masks during funeral ceremonies, initiation rites, and agricultural festivals. UNESCO inscribed Gule Wamkulu as Intangible Cultural Heritage of Humanity in 2005. The masks represent ancestral spirits, wild animals, and supernatural forces. Only fully initiated men are permitted to wear them. The red pigment used in this particular mask was sourced from ground ochre from the Dedza highlands. This piece dates to approximately 1880-1910.'
WHERE qr_code = 'CHW001';
```

---

## Step 2: New Dependencies

Add to `mtengatenga_ar/pubspec.yaml` under `dependencies`:

```yaml
google_generative_ai: ^0.4.3
flutter_tts: ^3.8.5
```

Run `flutter pub get` after adding.

---

## Step 3: Environment Variable

Add to `mtengatenga_ar/.env`:
```
GEMINI_API_KEY=your_gemini_api_key_here
```

The `.env.example` file already exists in the project. Add `GEMINI_API_KEY=` to it as well (without the value).

Get a free Gemini API key at: https://aistudio.google.com

---

## Step 4: Create Gemini AI Service

**File to create:** `mtengatenga_ar/lib/services/gemini_service.dart`

This service must:
- Initialize Gemini with the API key from `.env` using `flutter_dotenv`
- Use the `gemini-1.5-flash` model (free tier, fast)
- Accept an `Artifact` object and user message as input
- Return a streamed response string
- Have a `generateTourNarration(Artifact artifact, String narrationContext)` method
- Have a `chatAboutArtifact(Artifact artifact, String userMessage, List<Map<String,String>> history)` method
- Use this exact system prompt structure:

```
You are a knowledgeable, warm and engaging museum guide at Mtengatenga Cultural Museum in Malawi. 
You specialize in Malawian cultural heritage, Chewa traditions, and the artifacts in this museum.

Current artifact the visitor is viewing:
Name: {artifact.name}
Category: {artifact.category}
Period: {artifact.period}
Description: {artifact.description}
Cultural Context: {artifact.aiContext}

Guidelines:
- Only answer questions about this artifact or directly related Malawian cultural heritage
- Keep responses conversational and under 4 sentences unless the visitor asks for detail
- If asked about something unrelated to the museum, politely redirect to the artifact
- Use respectful language when discussing cultural and spiritual practices
- If ai_context is empty, use your knowledge of Malawian culture but be transparent about it
```

- Handle API errors gracefully — return a fallback string using the artifact's existing `description` field if Gemini fails
- Cache the last 10 messages of conversation history per artifact session

---

## Step 5: Update Artifact Model

**File:** `mtengatenga_ar/lib/models/artifact.dart`

Add `aiContext` field to the existing `Artifact` class:

```dart
final String? aiContext;
```

Update `fromJson` to read `ai_context` from Supabase:
```dart
aiContext: _asNullableString(json['ai_context']),
```

Update `toJson` to include:
```dart
'ai_context': aiContext,
```

---

## Step 6: Update SupabaseService

**File:** `mtengatenga_ar/lib/services/supabase_service.dart`

Add these methods to the existing `SupabaseService` class:

### `getActiveTours()`
Fetches all active guided tours from `guided_tours` table where `is_active = true`.
Returns `List<Map<String, dynamic>>`.

### `getTourStops(String tourId)`
Fetches all stops for a tour from `tour_stops` table ordered by `stop_order`.
Joins with artifact data using the `artifact_id` field.
Returns `List<Map<String, dynamic>>`.

---

## Step 7: Wire Up AiGuideScreen to Real Gemini

**File:** `mtengatenga_ar/lib/features/ai_guide/ai_guide_screen.dart`

This is the most important step. The UI must NOT change at all — only the data layer changes.

### Changes needed:

**1. Add optional artifact parameter to AiGuideScreen**

The screen should accept an optional `Artifact? artifact` parameter. When an artifact is provided (user came from QR scan), the AI is grounded to that artifact. When null (user opened AI guide from home), the AI acts as a general museum guide.

**2. Replace `_Mock.responses` with real Gemini calls**

The `_sendMessage()` method currently adds a mock response after a delay. Replace this with:
- Call `GeminiService.chatAboutArtifact(artifact, userMessage, _conversationHistory)`  
- Stream the response into the existing AI bubble widget
- Add a typing indicator while waiting (the UI already has this in voice mode — replicate for text)
- Maintain `_conversationHistory` as a `List<Map<String, String>>` of `{role: user/model, content: text}`

**3. Replace `_Mock.suggestions` with dynamic suggestions**

When an artifact is provided, generate context-aware suggestions based on the artifact's category and period. When no artifact, use general museum suggestions. These can still be hardcoded per category — no need to call Gemini for suggestions.

**4. Replace `_Mock.voiceResponse` with real Gemini call in voice mode**

The `_runDemoFlow()` method currently runs a fake demo. Replace with:
- Record user speech (use `speech_to_text` package or keep as text input for now)
- Call Gemini with the transcribed text
- Display response in the existing `_voiceResponseText()` widget
- Use `flutter_tts` to read the response aloud

**5. Wire up Tour Mode**

The tour banner already exists in the UI with hardcoded "Step 2 of 8". Wire it to real data:
- When tour mode is activated (route icon button), fetch active tours from Supabase
- Show a bottom sheet to select a tour
- Load tour stops and track current stop index
- Update the banner with real tour name and step count
- When a QR is scanned during tour mode, advance to the next stop automatically

---

## Step 8: Connect QR Scan to AI Guide

**File:** `mtengatenga_ar/lib/features/scan/scan_screen.dart`

After a successful QR scan and artifact load, the navigation should pass the artifact to `AiGuideScreen`. There should be a "Chat with AI Guide" button on the `ArtifactDetailsScreen` that opens `AiGuideScreen(artifact: artifact)`.

**File:** `mtengatenga_ar/lib/features/artifact/artifact_details_screen.dart`

Add a floating action button or prominent button that navigates to:
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => AiGuideScreen(artifact: currentArtifact),
));
```

---

## Step 9: Offline Fallback

When `connectivity_plus` detects no internet (already a dependency):
- Show a subtle "Offline Mode" banner at the top of AiGuideScreen
- Disable the text input and show: "AI guide requires internet. Browse artifact details below."
- Display the artifact's static `description` and `aiContext` fields as readable cards
- This ensures the app never shows an error — always shows something useful
- Cache the last conversation per artifact in `shared_preferences` (already a dependency)

---

## File Summary — What Claude Code Should Create/Modify

| Action | File | What to do |
|--------|------|-----------|
| **CREATE** | `lib/services/gemini_service.dart` | New Gemini AI service |
| **MODIFY** | `lib/models/artifact.dart` | Add `aiContext` field |
| **MODIFY** | `lib/services/supabase_service.dart` | Add tour methods |
| **MODIFY** | `lib/features/ai_guide/ai_guide_screen.dart` | Wire to Gemini, add artifact param |
| **MODIFY** | `lib/features/artifact/artifact_details_screen.dart` | Add AI Guide button |
| **MODIFY** | `mtengatenga_ar/pubspec.yaml` | Add google_generative_ai, flutter_tts |
| **MODIFY** | `mtengatenga_ar/.env` | Add GEMINI_API_KEY |
| **DB via MCP** | Supabase | Run all SQL from Step 1 |

---

## Implementation Order

Claude Code should implement in this exact order to avoid breaking the app:

1. Run Supabase SQL migrations (Step 1) using Supabase MCP
2. Add dependencies to pubspec.yaml (Step 2)
3. Add GEMINI_API_KEY to .env (Step 3)
4. Create `gemini_service.dart` (Step 4)
5. Update `artifact.dart` with aiContext (Step 5)
6. Update `supabase_service.dart` with tour methods (Step 6)
7. Wire `ai_guide_screen.dart` to Gemini (Step 7) — most complex step
8. Add AI Guide button to `artifact_details_screen.dart` (Step 8)
9. Add offline fallback (Step 9)

---

## Testing Checklist

After implementation, verify:

- [ ] AiGuideScreen loads without crash when no artifact passed
- [ ] AiGuideScreen loads without crash when artifact passed from QR scan
- [ ] Sending a message gets a real Gemini response (not mock)
- [ ] AI response is grounded to the artifact (doesn't answer off-topic questions)
- [ ] Voice mode plays response text using flutter_tts
- [ ] Tour mode loads real tours from Supabase
- [ ] Offline mode shows graceful fallback — no crash, no error screen
- [ ] Conversation history persists within the session
- [ ] Back navigation works from AiGuideScreen

---

## Important Notes for Claude Code

- **Do NOT change the UI in ai_guide_screen.dart** — it is visually complete and polished
- The app uses `AppColors` and `AppTokens` from `lib/theme/app_tokens.dart` — use the same tokens for any new UI
- The project uses `flutter_dotenv` for env vars — use `dotenv.env['GEMINI_API_KEY']` to access the key
- The project has Brick offline-first setup — for now, the AI guide does NOT need to use Brick; simple Supabase + SharedPreferences is sufficient
- All new Dart files should follow the existing code style: no unnecessary comments, clean separation of concerns
- The `SupabaseService` is injected via constructor — maintain this pattern for `GeminiService`
