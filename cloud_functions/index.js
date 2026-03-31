const express = require('express');
const functions = require('@google-cloud/functions-framework');
const { VertexAI } = require('@google-cloud/vertexai');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');
const { TranslationServiceClient } = require('@google-cloud/translate');
const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');

// Initialize firebase-admin using ADC (same GCP project, no credentials file needed)
admin.initializeApp();

const app = express();
app.use(express.json({ limit: '10mb' }));

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
  const { prompt, image } = req.body;
  if (!prompt) {
    return res.status(400).json({ error: 'Missing "prompt" in request body.' });
  }

  try {
    const model = getModel();

    const parts = [];
    if (image && image.data && image.mimeType) {
      parts.push({
        inlineData: {
          mimeType: image.mimeType,
          data: image.data,
        },
      });
    }
    parts.push({ text: prompt });

    const result = await model.generateContent({
      contents: [{ role: 'user', parts }],
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

// ── POST /translate — Cloud Translation ─────────────────────────────────────

const translationClient = new TranslationServiceClient();

app.post('/translate', async (req, res) => {
  const { text, targetLanguage } = req.body;
  if (!text || !targetLanguage) {
    return res.status(400).json({ error: 'Missing "text" or "targetLanguage".' });
  }

  if (targetLanguage === 'en') {
    return res.json({ translatedText: text });
  }

  try {
    const [response] = await translationClient.translateText({
      parent: `projects/${PROJECT_ID}/locations/global`,
      contents: [text],
      targetLanguageCode: targetLanguage,
      mimeType: 'text/plain',
    });

    const translatedText = response.translations[0].translatedText;
    res.json({ translatedText });
  } catch (err) {
    console.error('POST /translate error:', err.message || err);
    res.status(500).json({ error: err.message || 'Translation failed.' });
  }
});

// ── POST /embed-query — Generate text embedding via Vertex AI ───────────────

async function generateEmbedding(text) {
  const auth = new GoogleAuth();
  const client = await auth.getClient();
  const token = await client.getAccessToken();

  // Try models in order: text-embedding-005, text-embedding-004, textembedding-gecko@003
  const models = ['text-embedding-005', 'text-embedding-004', 'textembedding-gecko@003'];

  for (const model of models) {
    const url = `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${model}:predict`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        instances: [{ content: text }],
      }),
    });

    if (response.ok) {
      const data = await response.json();
      return data.predictions[0].embeddings.values;
    }

    // If 404 (model not found), try next model
    if (response.status === 404) {
      console.log(`Embedding model ${model} not found, trying next...`);
      continue;
    }

    // Other error — throw
    const body = await response.text();
    throw new Error(`Embedding API error (${response.status}): ${body}`);
  }

  throw new Error('No embedding model available. Enable Vertex AI API: gcloud services enable aiplatform.googleapis.com');
}

app.post('/embed-query', async (req, res) => {
  const { text } = req.body;
  if (!text) {
    return res.status(400).json({ error: 'Missing "text" in request body.' });
  }

  try {
    const embedding = await generateEmbedding(text);
    res.json({ embedding });
  } catch (err) {
    console.error('POST /embed-query error:', err.message || err);
    res.status(500).json({ error: err.message || 'Embedding generation failed.' });
  }
});

// ── POST /embed-single — Embed a single artifact by ID ─────────────────────

app.post('/embed-single', async (req, res) => {
  const { id } = req.body;
  if (!id) {
    return res.status(400).json({ error: 'Missing "id" in request body.' });
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({ error: 'SUPABASE_URL or SUPABASE_SERVICE_KEY not set.' });
  }

  try {
    const fetchRes = await fetch(
      `${supabaseUrl}/rest/v1/artifacts?id=eq.${id}&select=id,name,subtitle,category,period,description,cultural_significance,additional_notes,ai_context,location`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        },
      }
    );
    const artifacts = await fetchRes.json();
    if (!artifacts || artifacts.length === 0) {
      return res.status(404).json({ error: 'Artifact not found.' });
    }

    const artifact = artifacts[0];
    const doc = [
      artifact.name,
      artifact.subtitle,
      artifact.category,
      artifact.period ? `Period: ${artifact.period}` : null,
      artifact.description,
      artifact.cultural_significance ? `Cultural Significance: ${artifact.cultural_significance}` : null,
      artifact.additional_notes,
      artifact.ai_context,
      artifact.location ? `Location: ${artifact.location}` : null,
    ].filter(Boolean).join('. ');

    const embedding = await generateEmbedding(doc);

    await fetch(
      `${supabaseUrl}/rest/v1/artifacts?id=eq.${id}`,
      {
        method: 'PATCH',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({ embedding: JSON.stringify(embedding) }),
      }
    );

    res.json({ status: 'ok', id: artifact.id, name: artifact.name });
  } catch (err) {
    console.error('POST /embed-single error:', err.message || err);
    res.status(500).json({ error: err.message || 'Single embedding failed.' });
  }
});

// ── POST /embed-artifacts — One-time batch embedding ────────────────────────

app.post('/embed-artifacts', async (req, res) => {
  const { confirm } = req.body;
  if (confirm !== 'yes-embed-all') {
    return res.status(400).json({ error: 'Send { "confirm": "yes-embed-all" } to proceed.' });
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({ error: 'SUPABASE_URL or SUPABASE_SERVICE_KEY not set.' });
  }

  try {
    const listRes = await fetch(
      `${supabaseUrl}/rest/v1/artifacts?select=id,name,subtitle,category,period,description,cultural_significance,additional_notes,ai_context,location`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        },
      }
    );
    const artifacts = await listRes.json();

    const results = [];
    for (const artifact of artifacts) {
      const doc = [
        artifact.name,
        artifact.subtitle,
        artifact.category,
        artifact.period ? `Period: ${artifact.period}` : null,
        artifact.description,
        artifact.cultural_significance ? `Cultural Significance: ${artifact.cultural_significance}` : null,
        artifact.additional_notes,
        artifact.ai_context,
        artifact.location ? `Location: ${artifact.location}` : null,
      ].filter(Boolean).join('. ');

      try {
        const embedding = await generateEmbedding(doc);

        await fetch(
          `${supabaseUrl}/rest/v1/artifacts?id=eq.${artifact.id}`,
          {
            method: 'PATCH',
            headers: {
              'apikey': supabaseKey,
              'Authorization': `Bearer ${supabaseKey}`,
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: JSON.stringify({ embedding: JSON.stringify(embedding) }),
          }
        );

        results.push({ id: artifact.id, name: artifact.name, status: 'ok' });
      } catch (err) {
        results.push({ id: artifact.id, name: artifact.name, status: 'error', error: err.message });
      }
    }

    res.json({ embedded: results.filter(r => r.status === 'ok').length, total: artifacts.length, results });
  } catch (err) {
    console.error('POST /embed-artifacts error:', err.message || err);
    res.status(500).json({ error: err.message || 'Batch embedding failed.' });
  }
});

// ── POST /send-push — Send FCM push to all registered devices ──────────────

app.post('/send-push', async (req, res) => {
  const { notification_id, title, body, post_type, thumbnail_url } = req.body;
  if (!title || !body) {
    return res.status(400).json({ error: 'Missing title or body.' });
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({ error: 'SUPABASE_URL or SUPABASE_SERVICE_KEY not set.' });
  }

  try {
    // 1. Fetch all device tokens
    const tokenRes = await fetch(
      `${supabaseUrl}/rest/v1/device_tokens?select=fcm_token`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        },
      }
    );
    const tokenRows = await tokenRes.json();
    const tokens = tokenRows.map(r => r.fcm_token).filter(Boolean);

    if (tokens.length === 0) {
      return res.json({ sent: 0, message: 'No device tokens registered.' });
    }

    // 2. Build FCM message (batch in groups of 500 — FCM multicast limit)
    const batches = [];
    for (let i = 0; i < tokens.length; i += 500) {
      batches.push(tokens.slice(i, i + 500));
    }

    let totalSuccess = 0;
    let totalFailure = 0;
    const staleTokens = [];

    for (const batch of batches) {
      const message = {
        notification: { title, body },
        data: {
          notification_id: notification_id || '',
          post_type: post_type || '',
          thumbnail_url: thumbnail_url || '',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'museum_notifications',
            defaultSound: true,
          },
        },
        tokens: batch,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      totalSuccess += response.successCount;
      totalFailure += response.failureCount;

      // 3. Collect stale tokens for cleanup
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error &&
            (resp.error.code === 'messaging/registration-token-not-registered' ||
             resp.error.code === 'messaging/invalid-registration-token')) {
          staleTokens.push(batch[idx]);
        }
      });
    }

    // 4. Delete stale tokens from Supabase
    for (const stale of staleTokens) {
      await fetch(
        `${supabaseUrl}/rest/v1/device_tokens?fcm_token=eq.${encodeURIComponent(stale)}`,
        {
          method: 'DELETE',
          headers: {
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Prefer': 'return=minimal',
          },
        }
      );
    }

    res.json({ sent: totalSuccess, failed: totalFailure, staleRemoved: staleTokens.length });
  } catch (err) {
    console.error('POST /send-push error:', err.message || err);
    res.status(500).json({ error: err.message || 'Push notification failed.' });
  }
});

// ── Health check ────────────────────────────────────────────────────────────

app.get('/', (_req, res) => {
  res.json({ status: 'ok', service: 'mtengatenga-ai-proxy' });
});

// ── Register with Cloud Functions framework ─────────────────────────────────

functions.http('aiProxy', app);
