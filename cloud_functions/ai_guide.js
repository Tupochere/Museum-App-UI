const PROMPT_VERSION = 'ai-guide-v2';
const HISTORY_LIMITS = Object.freeze({
  text: 10,
  voice: 6,
  tour: 0,
});

const SUPPORTED_MODES = new Set(['text', 'voice', 'tour']);
const MUSEUM_DOMAIN_PATTERNS = [
  /\bartifact\b/i,
  /\bmuseum\b/i,
  /\bmalawi(?:an)?\b/i,
  /\bculture|cultural|heritage|tradition|traditional\b/i,
  /\bchewa\b/i,
  /\bnyau\b/i,
  /\bgule\b/i,
  /\bceremon(?:y|ies)\b/i,
  /\bmask|drum|instrument|dance|ritual\b/i,
  /\bexhibit|display|tour|gallery\b/i,
  /\bperiod|history|historical\b/i,
];
const COMPARISON_PATTERNS = [
  /\bcompare\b/i,
  /\bdifference\b/i,
  /\bdifferent\b/i,
  /\bsimilar\b/i,
  /\banother\b/i,
  /\bother artifacts?\b/i,
  /\bwhat else\b/i,
  /\blike this\b/i,
  /\brelated\b/i,
  /\bfeatured artifacts?\b/i,
];
const OUT_OF_SCOPE_PATTERNS = [
  /\bnba|football|soccer|premier league|baseball|cricket\b/i,
  /\bstock|crypto|bitcoin|forex\b/i,
  /\bweather\b/i,
  /\brecipe|cook|bake\b/i,
  /\bdebug|javascript|flutter code|python\b/i,
  /\bcapital of\b/i,
  /\bsolve\b.*\bequation\b/i,
];

/**
 * @typedef {Object} AiGuideMessage
 * @property {'user'|'model'} role
 * @property {string} content
 */

/**
 * @typedef {Object} AiGuideRequest
 * @property {string} query
 * @property {'text'|'voice'|'tour'} mode
 * @property {string | undefined} artifactId
 * @property {AiGuideMessage[]} history
 * @property {'en'|'ny'} language
 */

/**
 * @typedef {Object} ArtifactContext
 * @property {string} id
 * @property {string} name
 * @property {string | null | undefined} subtitle
 * @property {string | null | undefined} category
 * @property {string | null | undefined} period
 * @property {string | null | undefined} description
 * @property {string | null | undefined} culturalSignificance
 * @property {string | null | undefined} additionalNotes
 * @property {string | null | undefined} aiContext
 * @property {string | null | undefined} location
 * @property {Array<{year: string, event: string}>} timeline
 * @property {number | undefined} similarity
 */

/**
 * @typedef {Object} RetrievedSnippet
 * @property {string} id
 * @property {string} name
 * @property {number} similarity
 * @property {string | null | undefined} category
 * @property {string | null | undefined} period
 * @property {string | null | undefined} summary
 */

/**
 * @typedef {Object} PromptProfile
 * @property {'text'|'voice'|'tour'} mode
 * @property {number} temperature
 * @property {number} maxOutputTokens
 * @property {string} targetLength
 * @property {string} styleInstruction
 */

function sanitizeHistory(history) {
  if (!Array.isArray(history)) return [];

  return history
    .map((entry) => {
      const role = entry?.role === 'model' ? 'model' : entry?.role === 'user' ? 'user' : null;
      const content = typeof entry?.content === 'string' ? entry.content.trim() : '';
      if (!role || !content) return null;
      return { role, content };
    })
    .filter(Boolean);
}

function trimHistory(mode, history) {
  const limit = HISTORY_LIMITS[mode] ?? HISTORY_LIMITS.text;
  if (limit <= 0) return [];
  if (history.length <= limit) return history;
  return history.slice(history.length - limit);
}

function normalizeAiGuideRequest(body = {}) {
  const query = typeof body.query === 'string' ? body.query.trim() : '';
  if (!query) return null;

  const rawMode = typeof body.mode === 'string' ? body.mode.trim().toLowerCase() : 'text';
  const mode = SUPPORTED_MODES.has(rawMode) ? rawMode : 'text';
  const artifactId =
    typeof body.artifactId === 'string' && body.artifactId.trim() && body.artifactId.trim() !== 'general'
      ? body.artifactId.trim()
      : undefined;
  const language = body.language === 'ny' ? 'ny' : 'en';
  const history = trimHistory(mode, sanitizeHistory(body.history));

  return {
    query,
    mode,
    artifactId,
    history,
    language,
  };
}

function buildPromptProfile(mode) {
  switch (mode) {
    case 'voice':
      return {
        mode,
        temperature: 0.25,
        maxOutputTokens: 180,
        targetLength: '2 to 3 short sentences',
        styleInstruction:
          'Keep the answer natural, concise, and easy to follow out loud. Avoid lists unless the visitor explicitly asks for one.',
      };
    case 'tour':
      return {
        mode,
        temperature: 0.3,
        maxOutputTokens: 180,
        targetLength: '2 to 3 vivid narration sentences',
        styleInstruction:
          'Sound like a live museum guide standing beside the artifact. Lead with the most vivid and visitor-friendly detail.',
      };
    case 'text':
    default:
      return {
        mode: 'text',
        temperature: 0.4,
        maxOutputTokens: 320,
        targetLength: '3 to 5 short sentences',
        styleInstruction:
          'Be warm, clear, and conversational. Start with the direct answer, then add the most useful cultural context.',
      };
  }
}

function isMuseumDomainQuery(query) {
  return MUSEUM_DOMAIN_PATTERNS.some((pattern) => pattern.test(query));
}

function isOutOfScopeQuery(query) {
  return OUT_OF_SCOPE_PATTERNS.some((pattern) => pattern.test(query));
}

function determineRetrievalStrategy({ query, artifactId }) {
  const museumDomain = isMuseumDomainQuery(query);
  const outOfScope = !museumDomain && isOutOfScopeQuery(query);
  const comparison = COMPARISON_PATTERNS.some((pattern) => pattern.test(query));

  if (outOfScope) {
    return {
      route: 'out_of_scope',
      shouldRetrieve: false,
      museumDomain,
    };
  }

  if (artifactId && !comparison) {
    return {
      route: 'current_artifact',
      shouldRetrieve: false,
      museumDomain: true,
    };
  }

  if (artifactId && comparison) {
    return {
      route: 'compare_or_broad',
      shouldRetrieve: true,
      museumDomain: true,
    };
  }

  return {
    route: 'general_retrieval',
    shouldRetrieve: true,
    museumDomain,
  };
}

function buildSystemInstruction({ profile, language }) {
  const lines = [
    'You are the AI guide for Mtengatenga Cultural Museum in Malawi.',
    'Be knowledgeable, respectful, warm, and grounded in the provided museum evidence.',
    'Never invent exhibit facts, provenance details, dates, users, or ceremonial meanings that are not supported by the provided context.',
    'When the provided evidence is insufficient, say so plainly and keep the uncertainty concise.',
    'You may answer broader Malawian cultural questions, but clearly label that material as general cultural background instead of a fact about the exact artifact.',
    'If the visitor asks for something unrelated to the museum or Malawian cultural heritage, politely redirect them to museum topics.',
    'Use respectful language when discussing sacred, spiritual, or ceremonial practices.',
    `Keep the final answer to ${profile.targetLength}.`,
    profile.styleInstruction,
    'Answer in English only. Any translation happens after generation.',
  ];

  if (profile.mode === 'voice') {
    if (language === 'en') {
      lines.push(
        'Because an English TTS system may read this aloud, you may spell difficult Malawian names phonetically when needed for pronunciation. Do not show the original spelling next to the phonetic version.'
      );
    } else {
      lines.push('Use natural spellings for Malawian terms. Do not add phonetic pronunciation guides.');
    }
  }

  return lines.join(' ');
}

function buildArtifactContextBlock(context, label) {
  if (!context) return '';

  const timelineText = Array.isArray(context.timeline) && context.timeline.length > 0
    ? context.timeline
        .map((entry) => `${entry.year}: ${entry.event}`)
        .join('; ')
    : '';

  const lines = [
    label,
    `Name: ${context.name}`,
    context.subtitle ? `Subtitle: ${context.subtitle}` : '',
    context.category ? `Category: ${context.category}` : '',
    context.period ? `Period: ${context.period}` : '',
    context.description ? `Description: ${context.description}` : '',
    context.culturalSignificance ? `Cultural significance: ${context.culturalSignificance}` : '',
    context.additionalNotes ? `Additional notes: ${context.additionalNotes}` : '',
    context.aiContext ? `Museum guide notes: ${context.aiContext}` : '',
    context.location ? `Location: ${context.location}` : '',
    timelineText ? `Timeline: ${timelineText}` : '',
    typeof context.similarity === 'number' ? `Similarity score: ${context.similarity.toFixed(2)}` : '',
  ].filter(Boolean);

  return lines.join('\n');
}

function buildRetrievedSnippetBlock(snippets) {
  if (!Array.isArray(snippets) || snippets.length === 0) return '';

  const lines = ['SUPPORTING ARTIFACTS:'];
  for (const snippet of snippets) {
    const snippetLines = [
      `- ${snippet.name}`,
      snippet.category ? `  Category: ${snippet.category}` : '',
      snippet.period ? `  Period: ${snippet.period}` : '',
      snippet.summary ? `  Notes: ${snippet.summary}` : '',
      `  Similarity: ${snippet.similarity.toFixed(2)}`,
    ].filter(Boolean);
    lines.push(snippetLines.join('\n'));
  }

  return lines.join('\n');
}

function buildTaskPrompt({ request, route, artifactContext, retrievedSnippets, profile }) {
  const sections = [
    'GROUNDING RULES:',
    '- Prefer the selected artifact context when it exists.',
    '- Use supporting artifacts only when they help answer the visitor question.',
    '- If you use broader Malawian knowledge, explicitly label it as general cultural background.',
    '- If evidence is missing, say what is known and what is uncertain.',
    `- This turn is in ${profile.mode} mode.`,
    '',
    'MUSEUM OVERVIEW:',
    'Mtengatenga Cultural Museum helps visitors explore Malawian cultural heritage, with strong emphasis on Chewa traditions, artifacts, performances, and everyday cultural life.',
  ];

  if (artifactContext) {
    sections.push('', buildArtifactContextBlock(artifactContext, 'SELECTED ARTIFACT:'));
  }

  const snippetBlock = buildRetrievedSnippetBlock(retrievedSnippets);
  if (snippetBlock) {
    sections.push('', snippetBlock);
  }

  sections.push(
    '',
    `ROUTING DECISION: ${route.route}`,
    '',
    'VISITOR QUESTION:',
    request.query,
    '',
    'ANSWER THE VISITOR NOW:'
  );

  return sections.join('\n');
}

function toVertexHistory(history) {
  return history.map((entry) => ({
    role: entry.role,
    parts: [{ text: entry.content }],
  }));
}

function buildRetrievedSnippet(context) {
  if (!context) return null;

  const summaryParts = [
    context.description,
    context.culturalSignificance,
    context.aiContext,
    context.location ? `Location: ${context.location}` : null,
  ].filter(Boolean);

  return {
    id: context.id,
    name: context.name,
    similarity: typeof context.similarity === 'number' ? context.similarity : 0,
    category: context.category,
    period: context.period,
    summary: summaryParts.join(' '),
  };
}

function buildOutOfScopeMessage(mode) {
  if (mode === 'voice') {
    return 'I can help with Mtengatenga Cultural Museum and Malawian cultural heritage. Ask me about an artifact, a tradition, or what you can explore here.';
  }

  return 'I am here to help with Mtengatenga Cultural Museum and Malawian cultural heritage. Ask me about an artifact, a cultural tradition, or what you can explore in the museum.';
}

function formatSseData(payload) {
  return `data: ${typeof payload === 'string' ? payload : JSON.stringify(payload)}\n\n`;
}

module.exports = {
  PROMPT_VERSION,
  HISTORY_LIMITS,
  normalizeAiGuideRequest,
  sanitizeHistory,
  trimHistory,
  buildPromptProfile,
  isMuseumDomainQuery,
  isOutOfScopeQuery,
  determineRetrievalStrategy,
  buildSystemInstruction,
  buildTaskPrompt,
  buildArtifactContextBlock,
  buildRetrievedSnippet,
  buildOutOfScopeMessage,
  toVertexHistory,
  formatSseData,
};
