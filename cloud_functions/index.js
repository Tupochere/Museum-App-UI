const express = require('express');
const functions = require('@google-cloud/functions-framework');
const { VertexAI } = require('@google-cloud/vertexai');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');

const app = express();
app.use(express.json({ limit: '1mb' }));

// ── Vertex AI setup ─────────────────────────────────────────────────────────

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const LOCATION = process.env.VERTEX_LOCATION || 'us-central1';
const MODEL = process.env.VERTEX_MODEL || 'gemini-2.5-flash';

function getModel() {
  const vertexAI = new VertexAI({ project: PROJECT_ID, location: LOCATION });
  return vertexAI.getGenerativeModel({ model: MODEL });
}

// ── POST /ai-chat — non-streaming text generation ───────────────────────────

app.post('/ai-chat', async (req, res) => {
  const { prompt } = req.body;
  if (!prompt) {
    return res.status(400).json({ error: 'Missing "prompt" in request body.' });
  }

  try {
    const model = getModel();
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
    });

    const text = result.response?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return res.status(502).json({ error: 'Empty response from Vertex AI.' });
    }

    res.json({ text });
  } catch (err) {
    console.error('POST /ai-chat error:', err.message || err);
    res.status(500).json({ error: err.message || 'Internal server error.' });
  }
});

// ── POST /ai-chat-stream — SSE streaming text generation ────────────────────

app.post('/ai-chat-stream', async (req, res) => {
  const { prompt } = req.body;
  if (!prompt) {
    return res.status(400).json({ error: 'Missing "prompt" in request body.' });
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');

  try {
    const model = getModel();
    const streamResult = await model.generateContentStream({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
    });

    for await (const chunk of streamResult.stream) {
      const text = chunk.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text) {
        res.write(`data: ${JSON.stringify({ text })}\n\n`);
      }
    }

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    console.error('POST /ai-chat-stream error:', err.message || err);
    // If headers already sent, write error as SSE event then close.
    if (res.headersSent) {
      res.write(`data: ${JSON.stringify({ error: err.message })}\n\n`);
      res.write('data: [DONE]\n\n');
      res.end();
    } else {
      res.status(500).json({ error: err.message || 'Internal server error.' });
    }
  }
});

// ── POST /tts — Cloud Text-to-Speech ────────────────────────────────────────

const ttsClient = new TextToSpeechClient();

app.post('/tts', async (req, res) => {
  const { text, voice, languageCode } = req.body;
  if (!text) {
    return res.status(400).json({ error: 'Missing "text" in request body.' });
  }

  try {
    const [response] = await ttsClient.synthesizeSpeech({
      input: { text },
      voice: {
        languageCode: languageCode || 'en-US',
        name: voice || 'en-US-Journey-F',
      },
      audioConfig: {
        audioEncoding: 'LINEAR16',
        sampleRateHertz: 24000,
      },
    });

    const audioContent = response.audioContent.toString('base64');
    res.json({ audioContent });
  } catch (err) {
    console.error('POST /tts error:', err.message || err);
    res.status(500).json({ error: err.message || 'Internal server error.' });
  }
});

// ── Health check ────────────────────────────────────────────────────────────

app.get('/', (_req, res) => {
  res.json({ status: 'ok', service: 'mtengatenga-ai-proxy' });
});

// ── Register with Cloud Functions framework ─────────────────────────────────

functions.http('aiProxy', app);
