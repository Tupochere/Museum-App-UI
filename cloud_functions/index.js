const express = require('express');
const functions = require('@google-cloud/functions-framework');
const { VertexAI } = require('@google-cloud/vertexai');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');
const { TranslationServiceClient } = require('@google-cloud/translate');
const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');
const {
  PROMPT_VERSION,
  normalizeAiGuideRequest,
  buildPromptProfile,
  determineRetrievalStrategy,
  buildSystemInstruction,
  buildTaskPrompt,
  buildRetrievedSnippet,
  buildOutOfScopeMessage,
  toVertexHistory,
  formatSseData,
} = require('./ai_guide');

// Initialize firebase-admin using ADC (same GCP project, no credentials file needed)
admin.initializeApp();

const app = express();
app.use(express.json({ limit: '10mb' }));

// Vertex AI setup
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const LOCATION = process.env.VERTEX_LOCATION || 'us-central1';
const MODEL = process.env.VERTEX_MODEL || 'gemini-2.5-flash';
const GUIDE_MATCH_THRESHOLD = 0.45;
const GUIDE_MATCH_COUNT = 3;
const GUIDE_ARTIFACT_SELECT = [
  'id',
  'name',
  'subtitle',
  'category',
  'period',
  'description',
  'cultural_significance',
  'additional_notes',
  'ai_context',
  'location',
].join(',');

function getModel(options = {}) {
  const vertexAI = new VertexAI({ project: PROJECT_ID, location: LOCATION });
  return vertexAI.getGenerativeModel({ model: MODEL, ...options });
}

function getSupabaseConfig() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
  if (!supabaseUrl || !supabaseKey) return null;
  return { supabaseUrl, supabaseKey };
}

function createSupabaseHeaders(supabaseKey, extraHeaders = {}) {
  return {
    'apikey': supabaseKey,
    'Authorization': `Bearer ${supabaseKey}`,
    ...extraHeaders,
  };
}

async function fetchJson(url, options, context) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${context} failed (${response.status}): ${body}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

function extractTextFromCandidate(candidate) {
  if (!candidate?.content?.parts) return '';
  return candidate.content.parts
    .map((part) => part?.text || '')
    .join('')
    .trim();
}

function extractResponseText(response) {
  if (!response?.candidates?.length) return '';

  for (const candidate of response.candidates) {
    const text = extractTextFromCandidate(candidate);
    if (text) return text;
  }

  return '';
}

function normalizeArtifactRow(row, similarity) {
  if (!row?.id || !row?.name) return null;

  return {
    id: row.id,
    name: row.name,
    subtitle: row.subtitle || null,
    category: row.category || null,
    period: row.period || null,
    description: row.description || null,
    culturalSignificance: row.cultural_significance || null,
    additionalNotes: row.additional_notes || null,
    aiContext: row.ai_context || null,
    location: row.location || null,
    timeline: [],
    similarity: typeof similarity === 'number' ? similarity : undefined,
  };
}

async function fetchArtifactsByIds(ids) {
  const config = getSupabaseConfig();
  const uniqueIds = [...new Set(ids.filter(Boolean))];
  if (!config || uniqueIds.length === 0) return new Map();

  const params = new URLSearchParams();
  params.set('select', GUIDE_ARTIFACT_SELECT);
  params.set('id', `in.(${uniqueIds.join(',')})`);

  const rows = await fetchJson(
    `${config.supabaseUrl}/rest/v1/artifacts?${params.toString()}`,
    { headers: createSupabaseHeaders(config.supabaseKey) },
    'Fetch artifacts'
  );

  const artifacts = new Map();
  for (const row of rows || []) {
    const artifact = normalizeArtifactRow(row);
    if (artifact) {
      artifacts.set(artifact.id, artifact);
    }
  }

  return artifacts;
}

async function fetchTimelinesByArtifactIds(ids) {
  const config = getSupabaseConfig();
  const uniqueIds = [...new Set(ids.filter(Boolean))];
  if (!config || uniqueIds.length === 0) return new Map();

  const params = new URLSearchParams();
  params.set('select', 'artifact_id,year,event');
  params.set('artifact_id', `in.(${uniqueIds.join(',')})`);
  params.set('order', 'year');

  const rows = await fetchJson(
    `${config.supabaseUrl}/rest/v1/timeline_events?${params.toString()}`,
    { headers: createSupabaseHeaders(config.supabaseKey) },
    'Fetch timeline events'
  );

  const timelines = new Map();
  for (const row of rows || []) {
    if (!row?.artifact_id || !row?.year || !row?.event) continue;
    if (!timelines.has(row.artifact_id)) {
      timelines.set(row.artifact_id, []);
    }
    timelines.get(row.artifact_id).push({
      year: String(row.year),
      event: String(row.event),
    });
  }

  return timelines;
}

async function matchArtifactsByEmbedding(embedding, { excludeIds = [] } = {}) {
  const config = getSupabaseConfig();
  if (!config || !Array.isArray(embedding) || embedding.length === 0) return [];

  const rows = await fetchJson(
    `${config.supabaseUrl}/rest/v1/rpc/match_artifacts`,
    {
      method: 'POST',
      headers: createSupabaseHeaders(config.supabaseKey, {
        'Content-Type': 'application/json',
      }),
      body: JSON.stringify({
        query_embedding: JSON.stringify(embedding),
        match_threshold: GUIDE_MATCH_THRESHOLD,
        match_count: GUIDE_MATCH_COUNT + excludeIds.length,
      }),
    },
    'Match artifacts'
  );

  const excluded = new Set(excludeIds.filter(Boolean));
  return (rows || [])
    .filter((row) => row?.id && !excluded.has(row.id))
    .map((row) => ({
      id: row.id,
      similarity: Number(row.similarity || 0),
    }))
    .filter((row) => row.similarity >= GUIDE_MATCH_THRESHOLD)
    .sort((left, right) => right.similarity - left.similarity)
    .slice(0, GUIDE_MATCH_COUNT);
}

function hydrateArtifactContext(artifact, timelinesByArtifactId, similarity) {
  if (!artifact) return null;

  return {
    ...artifact,
    timeline: timelinesByArtifactId.get(artifact.id) || [],
    similarity: typeof similarity === 'number' ? similarity : artifact.similarity,
  };
}

async function loadAiGuideContext(aiRequest) {
  const route = determineRetrievalStrategy(aiRequest);
  if (route.route === 'out_of_scope') {
    return {
      route,
      artifactContext: null,
      retrievedSnippets: [],
      retrievedArtifactIds: [],
      similarityScores: [],
    };
  }

  const idsToFetch = new Set();
  if (aiRequest.artifactId) {
    idsToFetch.add(aiRequest.artifactId);
  }

  let matches = [];
  if (route.shouldRetrieve) {
    try {
      const embedding = await generateEmbedding(aiRequest.query);
      matches = await matchArtifactsByEmbedding(embedding, {
        excludeIds: aiRequest.artifactId ? [aiRequest.artifactId] : [],
      });
      for (const match of matches) {
        idsToFetch.add(match.id);
      }
    } catch (error) {
      console.warn('AI guide retrieval skipped:', error.message || error);
      matches = [];
    }
  }

  const artifactsById = await fetchArtifactsByIds([...idsToFetch]);
  const timelinesByArtifactId = await fetchTimelinesByArtifactIds([...idsToFetch]);
  const artifactContext = aiRequest.artifactId
    ? hydrateArtifactContext(
        artifactsById.get(aiRequest.artifactId),
        timelinesByArtifactId
      )
    : null;

  const retrievedSnippets = matches
    .map((match) =>
      buildRetrievedSnippet(
        hydrateArtifactContext(
          artifactsById.get(match.id),
          timelinesByArtifactId,
          match.similarity
        )
      )
    )
    .filter(Boolean);

  return {
    route,
    artifactContext,
    retrievedSnippets,
    retrievedArtifactIds: retrievedSnippets.map((snippet) => snippet.id),
    similarityScores: retrievedSnippets.map((snippet) =>
      Number(snippet.similarity.toFixed(2))
    ),
  };
}

function logAiGuideEvent(eventName, payload) {
  console.info(`AI guide ${eventName}:`, payload);
}

async function handleLegacyAiChat(req, res) {
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
    const text = extractResponseText(result.response);
    if (!text) {
      return res.status(502).json({ error: 'Empty response from Vertex AI.' });
    }

    res.json({ text });
  } catch (err) {
    console.error('POST /ai-chat legacy error:', err.message || err);
    res.status(500).json({ error: err.message || 'Internal server error.' });
  }
}

async function handleLegacyAiChatStream(req, res) {
  const { prompt } = req.body;
  if (!prompt) {
    return res.status(400).json({ error: 'Missing "prompt" in request body.' });
  }

  try {
    const model = getModel();
    const streamResult = await model.generateContentStream({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
    });

    for await (const chunk of streamResult.stream) {
      const text = extractResponseText(chunk);
      if (text) {
        res.write(formatSseData({ text }));
      }
    }

    res.write(formatSseData('[DONE]'));
    res.end();
  } catch (err) {
    console.error('POST /ai-chat-stream legacy error:', err.message || err);
    if (res.headersSent) {
      res.write(formatSseData({ error: err.message }));
      res.write(formatSseData('[DONE]'));
      res.end();
    } else {
      res.status(500).json({ error: err.message || 'Internal server error.' });
    }
  }
}

async function generateAiGuideResponse(aiRequest) {
  const profile = buildPromptProfile(aiRequest.mode);
  const guideContext = await loadAiGuideContext(aiRequest);

  if (guideContext.route.route === 'out_of_scope') {
    return {
      text: buildOutOfScopeMessage(aiRequest.mode),
      guideContext,
    };
  }

  const model = getModel({
    generationConfig: {
      temperature: profile.temperature,
      maxOutputTokens: profile.maxOutputTokens,
    },
    systemInstruction: buildSystemInstruction({
      profile,
      language: aiRequest.language,
    }),
  });
  const chat = model.startChat({
    history: toVertexHistory(aiRequest.history),
  });
  const result = await chat.sendMessage(
    buildTaskPrompt({
      request: aiRequest,
      route: guideContext.route,
      artifactContext: guideContext.artifactContext,
      retrievedSnippets: guideContext.retrievedSnippets,
      profile,
    })
  );

  return {
    text: extractResponseText(result.response),
    guideContext,
  };
}

async function streamAiGuideResponse(aiRequest, res) {
  const startedAt = Date.now();
  const profile = buildPromptProfile(aiRequest.mode);
  const guideContext = await loadAiGuideContext(aiRequest);
  let firstTokenLatencyMs = null;

  if (guideContext.route.route === 'out_of_scope') {
    res.write(formatSseData({ text: buildOutOfScopeMessage(aiRequest.mode) }));
    res.write(formatSseData('[DONE]'));
    res.end();
    return {
      guideContext,
      firstTokenLatencyMs: 0,
      totalLatencyMs: Date.now() - startedAt,
    };
  }

  const model = getModel({
    generationConfig: {
      temperature: profile.temperature,
      maxOutputTokens: profile.maxOutputTokens,
    },
    systemInstruction: buildSystemInstruction({
      profile,
      language: aiRequest.language,
    }),
  });
  const chat = model.startChat({
    history: toVertexHistory(aiRequest.history),
  });
  const streamResult = await chat.sendMessageStream(
    buildTaskPrompt({
      request: aiRequest,
      route: guideContext.route,
      artifactContext: guideContext.artifactContext,
      retrievedSnippets: guideContext.retrievedSnippets,
      profile,
    })
  );

  for await (const chunk of streamResult.stream) {
    const text = extractResponseText(chunk);
    if (!text) continue;
    if (firstTokenLatencyMs === null) {
      firstTokenLatencyMs = Date.now() - startedAt;
    }
    res.write(formatSseData({ text }));
  }

  res.write(formatSseData('[DONE]'));
  res.end();

  return {
    guideContext,
    firstTokenLatencyMs,
    totalLatencyMs: Date.now() - startedAt,
  };
}

// POST /ai-chat: structured AI guide or legacy prompt generation
app.post('/ai-chat', async (req, res) => {
  if (typeof req.body?.prompt === 'string' && !req.body?.query) {
    return handleLegacyAiChat(req, res);
  }

  const aiRequest = normalizeAiGuideRequest(req.body);
  if (!aiRequest) {
    return res.status(400).json({
      error: 'Missing or invalid "query" in request body.',
    });
  }

  const startedAt = Date.now();
  try {
    const { text, guideContext } = await generateAiGuideResponse(aiRequest);
    if (!text) {
      return res.status(502).json({ error: 'Empty response from Vertex AI.' });
    }

    logAiGuideEvent('response', {
      promptVersion: PROMPT_VERSION,
      mode: aiRequest.mode,
      artifactId: aiRequest.artifactId || null,
      route: guideContext.route.route,
      retrievedArtifactIds: guideContext.retrievedArtifactIds,
      similarityScores: guideContext.similarityScores,
      totalLatencyMs: Date.now() - startedAt,
    });

    res.json({ text });
  } catch (err) {
    console.error('POST /ai-chat error:', err.message || err);
    res.status(500).json({ error: err.message || 'Internal server error.' });
  }
});

// POST /ai-chat-stream: structured AI guide or legacy SSE streaming
app.post('/ai-chat-stream', async (req, res) => {
  if (typeof req.body?.prompt === 'string' && !req.body?.query) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    return handleLegacyAiChatStream(req, res);
  }

  const aiRequest = normalizeAiGuideRequest(req.body);
  if (!aiRequest) {
    return res.status(400).json({
      error: 'Missing or invalid "query" in request body.',
    });
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');

  try {
    const stats = await streamAiGuideResponse(aiRequest, res);
    logAiGuideEvent('stream', {
      promptVersion: PROMPT_VERSION,
      mode: aiRequest.mode,
      artifactId: aiRequest.artifactId || null,
      route: stats.guideContext.route.route,
      retrievedArtifactIds: stats.guideContext.retrievedArtifactIds,
      similarityScores: stats.guideContext.similarityScores,
      firstTokenLatencyMs: stats.firstTokenLatencyMs,
      totalLatencyMs: stats.totalLatencyMs,
    });
  } catch (err) {
    console.error('POST /ai-chat-stream error:', err.message || err);
    if (res.headersSent) {
      res.write(formatSseData({ error: err.message }));
      res.write(formatSseData('[DONE]'));
      res.end();
    } else {
      res.status(500).json({ error: err.message || 'Internal server error.' });
    }
  }
});

// POST /tts: Cloud Text-to-Speech
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

// POST /translate: Cloud Translation
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

// POST /embed-query: Generate text embedding via Vertex AI
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

    if (response.status === 404) {
      console.log(`Embedding model ${model} not found, trying next...`);
      continue;
    }

    const body = await response.text();
    throw new Error(`Embedding API error (${response.status}): ${body}`);
  }

  throw new Error(
    'No embedding model available. Enable Vertex AI API: gcloud services enable aiplatform.googleapis.com'
  );
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

// POST /embed-single: Embed a single artifact by ID
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
      artifact.cultural_significance
        ? `Cultural Significance: ${artifact.cultural_significance}`
        : null,
      artifact.additional_notes,
      artifact.ai_context,
      artifact.location ? `Location: ${artifact.location}` : null,
    ]
      .filter(Boolean)
      .join('. ');

    const embedding = await generateEmbedding(doc);

    await fetch(`${supabaseUrl}/rest/v1/artifacts?id=eq.${id}`, {
      method: 'PATCH',
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({ embedding: JSON.stringify(embedding) }),
    });

    res.json({ status: 'ok', id: artifact.id, name: artifact.name });
  } catch (err) {
    console.error('POST /embed-single error:', err.message || err);
    res.status(500).json({ error: err.message || 'Single embedding failed.' });
  }
});

// POST /embed-artifacts: One-time batch embedding
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
        artifact.cultural_significance
          ? `Cultural Significance: ${artifact.cultural_significance}`
          : null,
        artifact.additional_notes,
        artifact.ai_context,
        artifact.location ? `Location: ${artifact.location}` : null,
      ]
        .filter(Boolean)
        .join('. ');

      try {
        const embedding = await generateEmbedding(doc);

        await fetch(`${supabaseUrl}/rest/v1/artifacts?id=eq.${artifact.id}`, {
          method: 'PATCH',
          headers: {
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: JSON.stringify({ embedding: JSON.stringify(embedding) }),
        });

        results.push({ id: artifact.id, name: artifact.name, status: 'ok' });
      } catch (err) {
        results.push({
          id: artifact.id,
          name: artifact.name,
          status: 'error',
          error: err.message,
        });
      }
    }

    res.json({
      embedded: results.filter((result) => result.status === 'ok').length,
      total: artifacts.length,
      results,
    });
  } catch (err) {
    console.error('POST /embed-artifacts error:', err.message || err);
    res.status(500).json({ error: err.message || 'Batch embedding failed.' });
  }
});

// ── Object identification (vision → artifact) ──────────────────────────────

const IDENTIFY_ARTIFACT_SELECT = [
  'id',
  'name',
  'subtitle',
  'category',
  'period',
  'description',
  'ai_context',
].join(',');

async function loadArtifactCatalog() {
  const config = getSupabaseConfig();
  if (!config) return [];

  const params = new URLSearchParams();
  params.set('select', IDENTIFY_ARTIFACT_SELECT);
  params.set('order', 'name.asc');

  const rows = await fetchJson(
    `${config.supabaseUrl}/rest/v1/artifacts?${params.toString()}`,
    { headers: createSupabaseHeaders(config.supabaseKey) },
    'Fetch artifact catalog'
  );

  return (rows || []).filter((row) => row?.id && row?.name);
}

function buildIdentificationCatalogText(catalog) {
  return catalog
    .map((row, idx) => {
      const lines = [
        `${idx + 1}. id: ${row.id}`,
        `   name: ${row.name}`,
        row.subtitle ? `   subtitle: ${row.subtitle}` : '',
        row.category ? `   category: ${row.category}` : '',
        row.period ? `   period: ${row.period}` : '',
        row.description ? `   description: ${row.description}` : '',
        row.ai_context ? `   visual_cues: ${row.ai_context}` : '',
      ].filter(Boolean);
      return lines.join('\n');
    })
    .join('\n\n');
}

const IDENTIFY_RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    artifactId: {
      type: 'string',
      description:
        'The id of the matching artifact from the catalog, or empty string if none matches confidently.',
    },
    confidence: {
      type: 'number',
      description: 'Confidence in the match between 0.0 and 1.0.',
    },
    reasoning: {
      type: 'string',
      description: 'Brief one-sentence reason for the match or no-match.',
    },
    description: {
      type: 'string',
      description:
        'When no confident match, a short visitor-facing description of what is in the image.',
    },
  },
  required: ['artifactId', 'confidence', 'reasoning', 'description'],
};

function safeParseJson(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch (_) {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]);
    } catch (_) {
      return null;
    }
  }
}

app.post('/identify-artifact', async (req, res) => {
  const { image } = req.body || {};
  if (!image?.data || !image?.mimeType) {
    return res
      .status(400)
      .json({ error: 'Missing "image.data" / "image.mimeType" in request body.' });
  }

  try {
    const catalog = await loadArtifactCatalog();
    if (catalog.length === 0) {
      return res.status(503).json({
        error:
          'No artifacts available for identification. Check Supabase configuration.',
      });
    }

    const catalogText = buildIdentificationCatalogText(catalog);
    const systemInstruction = [
      'You are a museum artifact identification assistant for Mtengatenga Cultural Museum in Malawi.',
      'You will be given a photo a visitor took with their phone, plus a catalog of every artifact currently on display.',
      'Decide whether the photo shows ANY of the catalog artifacts.',
      'Only return an artifactId if you are confident the catalog visual cues match the image. If the photo could plausibly be the artifact, return it with appropriate confidence; if it is clearly something else (food, person, building, animal, unrelated object), return artifactId="" and describe what you see in 1-2 short sentences.',
      'Confidence guidelines: 0.85+ very confident match, 0.6-0.85 plausible match, below 0.6 means treat as no match (return empty artifactId).',
      'Never invent ids that are not in the catalog.',
    ].join(' ');

    const userPrompt = [
      'CATALOG (id + identifying details):',
      catalogText,
      '',
      'Identify the artifact in the attached image. Respond ONLY with the JSON object matching the schema.',
    ].join('\n');

    const model = getModel({
      systemInstruction,
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 400,
        responseMimeType: 'application/json',
        responseSchema: IDENTIFY_RESPONSE_SCHEMA,
      },
    });

    const result = await model.generateContent({
      contents: [
        {
          role: 'user',
          parts: [
            { inlineData: { mimeType: image.mimeType, data: image.data } },
            { text: userPrompt },
          ],
        },
      ],
    });

    const text = extractResponseText(result.response);
    const parsed = safeParseJson(text);
    if (!parsed) {
      console.error('identify-artifact: failed to parse JSON. Raw:', text);
      return res.status(502).json({ error: 'Identification model returned malformed JSON.' });
    }

    const artifactId = typeof parsed.artifactId === 'string' ? parsed.artifactId.trim() : '';
    const confidence = Number(parsed.confidence);
    const safeConfidence =
      Number.isFinite(confidence) ? Math.max(0, Math.min(1, confidence)) : 0;
    const reasoning = typeof parsed.reasoning === 'string' ? parsed.reasoning : '';
    const description = typeof parsed.description === 'string' ? parsed.description : '';

    const inCatalog = artifactId && catalog.some((row) => row.id === artifactId);
    const finalArtifactId = inCatalog ? artifactId : '';

    console.info('identify-artifact:', {
      artifactId: finalArtifactId,
      confidence: safeConfidence,
      catalogSize: catalog.length,
    });

    res.json({
      artifactId: finalArtifactId,
      confidence: safeConfidence,
      reasoning,
      description,
    });
  } catch (err) {
    console.error('POST /identify-artifact error:', err.message || err);
    res.status(500).json({ error: err.message || 'Artifact identification failed.' });
  }
});

// POST /send-push: Send FCM push to all registered devices
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
    const tokenRes = await fetch(`${supabaseUrl}/rest/v1/device_tokens?select=fcm_token`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
      },
    });
    const tokenRows = await tokenRes.json();
    const tokens = tokenRows.map((row) => row.fcm_token).filter(Boolean);

    if (tokens.length === 0) {
      return res.json({ sent: 0, message: 'No device tokens registered.' });
    }

    const batches = [];
    for (let index = 0; index < tokens.length; index += 500) {
      batches.push(tokens.slice(index, index + 500));
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

      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          console.error(
            `FCM send failed for token ${batch[idx].substring(0, 20)}...: ${resp.error.code} - ${resp.error.message}`
          );
          if (
            resp.error.code === 'messaging/registration-token-not-registered' ||
            resp.error.code === 'messaging/invalid-registration-token'
          ) {
            staleTokens.push(batch[idx]);
          }
        }
      });
    }

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

    res.json({
      sent: totalSuccess,
      failed: totalFailure,
      staleRemoved: staleTokens.length,
    });
  } catch (err) {
    console.error('POST /send-push error:', err.message || err);
    res.status(500).json({ error: err.message || 'Push notification failed.' });
  }
});

// Health check
app.get('/', (_req, res) => {
  res.json({ status: 'ok', service: 'mtengatenga-ai-proxy' });
});

// Register with Cloud Functions framework
functions.http('aiProxy', app);

module.exports = {
  app,
  getModel,
  loadAiGuideContext,
  generateAiGuideResponse,
  streamAiGuideResponse,
};
