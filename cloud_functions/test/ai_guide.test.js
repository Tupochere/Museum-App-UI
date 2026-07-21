const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  HISTORY_LIMITS,
  normalizeAiGuideRequest,
  trimHistory,
  buildPromptProfile,
  determineRetrievalStrategy,
  buildTaskPrompt,
  buildOutOfScopeMessage,
  formatSseData,
} = require('../ai_guide');

test('normalizeAiGuideRequest applies defaults and trims history', () => {
  const history = Array.from({ length: 12 }, (_, index) => ({
    role: index % 2 === 0 ? 'user' : 'model',
    content: `message ${index}`,
  }));

  const request = normalizeAiGuideRequest({
    query: ' Tell me about this artifact ',
    mode: 'text',
    artifactId: 'artifact-123',
    history,
    language: 'ny',
  });

  assert.equal(request.query, 'Tell me about this artifact');
  assert.equal(request.mode, 'text');
  assert.equal(request.artifactId, 'artifact-123');
  assert.equal(request.language, 'ny');
  assert.equal(request.history.length, HISTORY_LIMITS.text);
  assert.equal(request.history[0].content, 'message 2');
});

test('trimHistory removes all history for tour mode', () => {
  const history = [
    { role: 'user', content: 'one' },
    { role: 'model', content: 'two' },
  ];

  assert.deepEqual(trimHistory('tour', history), []);
});

test('buildPromptProfile returns the expected generation settings', () => {
  assert.deepEqual(buildPromptProfile('text'), {
    mode: 'text',
    temperature: 0.4,
    maxOutputTokens: 320,
    targetLength: '3 to 5 short sentences',
    styleInstruction:
      'Be warm, clear, and conversational. Start with the direct answer, then add the most useful cultural context.',
  });

  assert.deepEqual(buildPromptProfile('voice'), {
    mode: 'voice',
    temperature: 0.25,
    maxOutputTokens: 180,
    targetLength: '2 to 3 short sentences',
    styleInstruction:
      'Keep the answer natural, concise, and easy to follow out loud. Avoid lists unless the visitor explicitly asks for one.',
  });
});

test('determineRetrievalStrategy routes artifact, comparison, and out-of-scope prompts', () => {
  assert.deepEqual(
    determineRetrievalStrategy({
      query: 'Who used it?',
      artifactId: 'artifact-1',
    }),
    {
      route: 'current_artifact',
      shouldRetrieve: false,
      museumDomain: true,
    }
  );

  assert.deepEqual(
    determineRetrievalStrategy({
      query: 'What other artifact here is similar to this one?',
      artifactId: 'artifact-1',
    }),
    {
      route: 'compare_or_broad',
      shouldRetrieve: true,
      museumDomain: true,
    }
  );

  assert.deepEqual(
    determineRetrievalStrategy({
      query: 'Who won the NBA finals?',
      artifactId: undefined,
    }),
    {
      route: 'out_of_scope',
      shouldRetrieve: false,
      museumDomain: false,
    }
  );
});

test('buildTaskPrompt includes grounding sections and the visitor question', () => {
  const prompt = buildTaskPrompt({
    request: {
      query: 'What was this used for?',
      mode: 'text',
    },
    route: { route: 'current_artifact' },
    artifactContext: {
      id: 'artifact-1',
      name: 'Kaligo Drum',
      category: 'Instrument',
      period: '19th century',
      description: 'A ceremonial drum used during community events.',
      culturalSignificance: 'Associated with collective performance.',
      additionalNotes: null,
      aiContext: 'Handled with respect during performances.',
      location: 'Gallery A',
      timeline: [{ year: '1890', event: 'Referenced in oral histories.' }],
    },
    retrievedSnippets: [],
    profile: buildPromptProfile('text'),
  });

  assert.match(prompt, /SELECTED ARTIFACT:/);
  assert.match(prompt, /Kaligo Drum/);
  assert.match(prompt, /VISITOR QUESTION:\nWhat was this used for\?/);
});

test('buildOutOfScopeMessage stays museum-focused', () => {
  assert.match(buildOutOfScopeMessage('text'), /Mtengatenga Cultural Museum/);
  assert.match(buildOutOfScopeMessage('voice'), /Malawian cultural heritage/);
});

test('formatSseData preserves the existing SSE wire format', () => {
  assert.equal(formatSseData({ text: 'hello' }), 'data: {"text":"hello"}\n\n');
  assert.equal(formatSseData('[DONE]'), 'data: [DONE]\n\n');
});

test('regression fixture file contains at least 20 representative prompts', () => {
  const fixturePath = path.join(
    __dirname,
    'fixtures',
    'ai_guide_regression_cases.json'
  );
  const fixtures = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

  assert.ok(Array.isArray(fixtures));
  assert.ok(fixtures.length >= 20);
  for (const fixture of fixtures) {
    assert.ok(fixture.id);
    assert.ok(fixture.mode);
    assert.ok(fixture.category);
    assert.ok(fixture.query);
    assert.ok(fixture.expectation);
  }
});
