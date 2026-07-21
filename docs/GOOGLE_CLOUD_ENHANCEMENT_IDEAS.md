# Google Cloud Enhancements — Demo Day Plan

> **Context**: Final-year Information Systems computing project. Demo day is **April 12, 2026** — live demonstration to two supervisors. No real end-users. Goal is a functional, impressive MVP that shows technical depth and innovation.
>
> **Budget**: ~$50 from $300 Google Cloud credits (expires June 2026)
> **Time**: ~2 weeks of development

---

## The Demo-Day Mindset

Supervisors want to see:
1. **It actually works** — nothing crashes, no spinners that hang, no "sorry, rate limit" errors
2. **Technical depth** — not just CRUD, but meaningful integration of modern technologies
3. **Innovation in context** — a museum app built for Malawi, not a generic template
4. **You understand what you built** — every Google Cloud service should tie back to a clear WHY

Everything below is chosen because it **demos well in 15-30 minutes** and shows real functionality.

---

## Priority 1 — Make the Demo Bulletproof

### 1. Vertex AI Proxy (Fix Rate Limits)

**The problem you'll explain**: "The free Gemini API has strict rate limits. During development I kept hitting 429 errors mid-conversation. For a reliable demo, I moved the AI calls to Google Cloud's Vertex AI, which uses the same Gemini model but with production-grade quotas."

**What it does**: A single Cloud Function sits between the app and Gemini. The app sends requests to your Cloud Function → Cloud Function calls Vertex AI → returns the response. Same model (gemini-2.5-flash), no more rate limits.


**Why supervisors care**: Shows you understand the difference between prototyping with free APIs vs. architecting for reliability. Shows backend/cloud skills beyond just Flutter.

**Demo moment**: Have a full AI Guide conversation about an artifact without any failures. Ask 5-6 questions in a row — no 429 errors.

**Cost**: ~$2-3 for the entire demo period.

---

### 2. Cloud Text-to-Speech (Reliable Voice)

**The problem you'll explain**: "I explored multiple TTS providers — Gemini's experimental TTS, OpenAI, ElevenLabs, and an on-device model called Kokoro. For the demo I settled on Google Cloud's Neural2 voices because they're production-grade and have consistent quality."

**What it does**: The AI Guide speaks artifact descriptions and answers using a natural-sounding Google Cloud voice. Already partially integrated (`GoogleCloudTtsService` exists) — just needs to be promoted to the default provider.

**Why supervisors care**: Voice interaction shows a complete UX loop — scan → read → ask → listen. It transforms the app from "a screen you read" to "a guide that talks to you."

**Demo moment**: Ask the AI Guide about an artifact in voice mode. The response comes back as natural speech synced with text appearing on screen.

**Cost**: Essentially free for demo usage (~5,000 characters of speech = $0.00008).

---

## Priority 2 — Features That Make Supervisors Say "Wow"

### 3. Cloud Translation API (Multilingual Museum Guide)

**The problem you'll explain**: "Malawi's museums serve local visitors who speak Chichewa and international tourists who speak English, French, Portuguese. Rather than manually translating every artifact description, I integrated Google Cloud Translation to provide real-time multilingual support."

**What it does**:
- Add a language selector to the AI Guide and artifact detail screens
- When the user picks a language, the app sends the text through the Cloud Translation API
- The AI Guide can respond in the selected language
- Artifact descriptions translate on-the-fly

**Languages for demo**: English, Chichewa, French, Portuguese (covers Malawi's real visitor demographics)

**Why supervisors care**: This is the most IS-relevant feature — it shows you thought about the **information needs of diverse users** in a real-world Malawian context. It's not just technically impressive, it's contextually intelligent.

**Demo moment**: Switch languages mid-conversation. Show the same artifact description in English, then Chichewa, then French. "This one API call makes the museum accessible to any visitor."

**Cost**: ~$1-2 for all demo usage.

---

### 4. Gemini Vision — "Point and Learn" (Visual Artifact Recognition)

**The problem you'll explain**: "QR codes work, but what if a visitor just wants to point their phone at something and learn about it? I used Gemini's multimodal capabilities to let visitors take a photo of an artifact and ask questions about what they see."

**What it does**:
- New "Visual Scan" button alongside the existing QR scanner
- Visitor takes a photo of an artifact or any object in the museum
- Photo + question is sent to Gemini 2.5 Flash (which supports image input) via your Vertex AI proxy
- Gemini describes what it sees and provides cultural context
- If the object matches a known artifact in the database, it links to the full artifact detail

**Why supervisors care**: This is the standout feature. It combines computer vision + AI + your museum database into one seamless experience. It shows mastery of multimodal AI, not just text chat.

**Demo moment**: Take a live photo of an artifact (or a printed photo of one) during the presentation. The AI describes it, identifies it, and offers to tell you more. This is your "mic drop" moment.

**Cost**: ~$1-2 for demo usage (Gemini Vision on Vertex AI is very cheap).

---

### 5. Vertex AI Embeddings + Semantic Search

**The problem you'll explain**: "Traditional search matches keywords. But museum visitors think in concepts — 'show me ceremonial objects' or 'what relates to Lake Malawi fishing.' I used Vertex AI text embeddings to enable semantic search that understands meaning, not just words."

**What it does**:
- Pre-compute vector embeddings for all artifact descriptions using `text-embedding-005`
- Store embeddings in Supabase (using pgvector extension)
- Add a search bar to the home screen
- User types a natural language query → embed it → find closest matching artifacts
- Show results ranked by relevance

**Why supervisors care**: Demonstrates understanding of vector databases, similarity search, and modern AI-powered information retrieval — core IS concepts.

**Demo moment**: Type "wooden objects used in ceremonies" and get back relevant artifacts — even if none of them contain that exact phrase. Then type "tools for daily life" and get a completely different, equally relevant set.

**Cost**: One-time embedding generation < $0.01. Search queries are negligible.

---

## Priority 3 — Polish the Full Loop

### 6. Cloud Functions as Unified Backend

**The problem you'll explain**: "Rather than putting multiple API keys on the mobile device, I created a lightweight Cloud Functions backend that handles all Google Cloud API calls. This follows the industry-standard pattern of keeping credentials server-side."

**What it does**: One Cloud Functions project with endpoints for:
- `/ai-chat` — Vertex AI Gemini (text conversation)
- `/ai-vision` — Vertex AI Gemini (photo + question)
- `/tts` — Cloud Text-to-Speech
- `/translate` — Cloud Translation
- `/embed` — Vertex AI Embeddings (for search)

**Why supervisors care**: Shows you understand backend architecture, not just mobile development. The app isn't just a frontend — it has a proper API layer. This is an IS skill.

**Demo moment**: "All five of these Google Cloud services are accessed through a single Cloud Functions backend. The mobile app only needs one URL."

**Cost**: Cloud Functions free tier covers 2M invocations/month. Effectively $0.

---

## What We're NOT Doing (and Why)

| Feature | Why not now |
|---|---|
| Firebase Analytics | No real users to analyze — add post-graduation |
| Crashlytics | Useful for production, overkill for a supervised demo |
| Push Notifications (FCM) | No users to push to — the notification feed already works in-app |
| Cloud CDN | Image load times are fine for a demo |
| Remote Config | You control the demo device — just set values in .env |
| Indoor Mapping | Too complex for 2 weeks, and the UI mockup already shows the concept |
| Visitor Profiles | No returning visitors in a demo context |
| Cloud Armor / Security | Important for production, irrelevant for demo day |

These are all valid post-graduation enhancements. Mention them in your report's "Future Work" section.

---

## Implementation Timeline

| Week | What | Days |
|---|---|---|
| **Week 1** (Mar 29 - Apr 4) | Cloud Function backend + Vertex AI proxy + Cloud TTS default | 3-4 days |
| | Cloud Translation integration (language selector + translate endpoint) | 2 days |
| **Week 2** (Apr 5 - Apr 11) | Gemini Vision "Point and Learn" feature | 2-3 days |
| | Semantic search (embeddings + pgvector + search UI) | 2 days |
| | Polish, test full demo flow, fix edge cases | 1-2 days |
| **Apr 12** | Demo day | |

---

## Demo Script Outline

This is how you'd walk supervisors through the app in ~20 minutes:

1. **Home screen** — "This is Mtengatenga Museum's mobile app, built with Flutter and backed by Supabase."

2. **QR Scan → Artifact Details** — Scan a code, show the full artifact page with images, timeline, description. "All data syncs from Supabase with offline-first caching via Brick ORM."

3. **AI Guide (text)** — Tap "Ask AI Guide", ask about the artifact. "This uses Google's Gemini 2.5 Flash model, routed through a Cloud Functions backend on Google Cloud's Vertex AI."

4. **AI Guide (voice)** — Switch to voice mode. Ask a question by speaking. AI responds with speech. "Speech-to-text captures the question, Gemini generates the answer, and Google Cloud Text-to-Speech speaks it back."

5. **Language switch** — Change language to Chichewa. Ask the same question. AI responds in Chichewa. Switch to French. "Google Cloud Translation API enables real-time multilingual support — critical for a museum in Malawi that serves both local and international visitors."

6. **Visual scan** — "But what if there's no QR code?" Take a photo of an artifact. AI describes what it sees and links to the database entry. "This uses Gemini's multimodal capabilities — the same model processes both text and images."

7. **Semantic search** — Go to search. Type "objects used in farming." Show relevant results. "Traditional search matches keywords. This uses Vertex AI text embeddings and vector similarity search to understand meaning."

8. **Events & Notifications** — Show the live events feed. "The admin dashboard publishes events, and the app receives them in real-time via Supabase Realtime subscriptions."

9. **Tickets** — Quick walkthrough of the ticket purchase flow with PayChangu integration.

10. **Architecture slide** — "Here's how it all connects." (Show the diagram below in your presentation.)

---

## Architecture Diagram (for your presentation)

```
┌──────────────────────────────────┐
│     Mtengatenga Museum App       │
│          (Flutter)               │
│                                  │
│  QR Scan  │ AI Guide │ AR View  │
│  Visual   │ Voice    │ Events   │
│  Search   │ Tickets  │ Map      │
└─────────────┬────────────────────┘
              │ HTTPS
              ▼
┌──────────────────────────────────┐
│    Google Cloud Functions        │
│        (API Gateway)             │
│                                  │
│  /ai-chat    → Vertex AI Gemini  │
│  /ai-vision  → Vertex AI Gemini  │
│  /tts        → Cloud TTS         │
│  /translate  → Cloud Translation  │
│  /embed      → Vertex AI Embed.  │
└──────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────┐
│         Supabase                 │
│  PostgreSQL + pgvector           │
│  Realtime subscriptions          │
│  Storage (images, thumbnails)    │
│  RLS (row-level security)        │
└──────────────────────────────────┘
```

---

## Google Cloud Services Summary (for your report)

| Service | Purpose in App | Why This Service |
|---|---|---|
| **Vertex AI (Gemini 2.5 Flash)** | AI Guide conversation + visual recognition | Production-grade access to Gemini with no rate limits |
| **Cloud Text-to-Speech** | Voice output for AI Guide | Neural2 voices sound natural; consistent quality |
| **Cloud Translation** | Multilingual artifact descriptions and AI responses | Supports 100+ languages; critical for Malawi's multilingual context |
| **Vertex AI Embeddings** | Semantic search across artifacts | Enables concept-based discovery, not just keyword matching |
| **Cloud Functions** | Backend API proxy for all services above | Keeps credentials server-side; single integration point |

**Total estimated cost for development + demo**: $10-15 (well within the $300 credits)
