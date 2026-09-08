// Deck queue integration tests: real temp SQLite DB, mocked AI + enrichment.
// Run: npx jest tests/decks.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `deckqueue-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'deck-queue-test-secret-1234567890';

// Mock Fanar/OpenRouter before ai-engine loads.
jest.mock('../services/ai', () => ({
  callAI: jest.fn(),
  callAIRaw: jest.fn(),
  callFanarRaw: jest.fn(),
  callOpenRouterRaw: jest.fn(),
  callFanar: jest.fn(),
  callOpenRouter: jest.fn(),
  parseAiJson: jest.fn((s) => JSON.parse(s)),
}));

const fanar = require('../services/ai');

const CARDS = (tag) => [
  {
    type: 'personalized_insight',
    journalExcerpt: `excerpt ${tag}`,
    insight: `insight ${tag}`,
    quote: 'quote',
    reference: 'Quran 2:286',
  },
  { type: 'surah_guidance', reference: '2:286', explanation: `explanation ${tag}` },
  {
    type: 'story_and_task',
    story: `story ${tag}`,
    storyReference: 'Src',
    lesson: 'lesson',
    taskTitle: 'Do one thing',
    taskDescription: 'desc',
  },
];

// Mock alquran.cloud enrichment (2 fetches per surah card).
function mockEnrichFetch() {
  global.fetch = jest.fn(async (url) => {
    const u = String(url);
    if (u.includes('/ar.alafasy')) {
      return { ok: true, json: async () => ({ data: { audio: 'https://audio.test/x.mp3' } }) };
    }
    return {
      ok: true,
      json: async () => ({
        data: [
          { text: 'arabic', number: 100, surah: { englishName: 'Al-Baqarah' }, numberInSurah: 286 },
          { text: 'translit' },
          { text: 'english' },
        ],
      }),
    };
  });
}

let db;
let decks;
let upsertJournal;
let upsertUser;
let pollPendingJournals;

beforeAll(async () => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
  mockEnrichFetch();
  const { initDB } = require('../lib/schema');
  await initDB();
  db = require('../lib/db');
  decks = require('../lib/decks');
  ({ upsertJournal } = require('../lib/journals'));
  ({ upsertUser } = require('../lib/users'));
  ({ pollPendingJournals } = require('../lib/ai-engine'));
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

async function clean() {
  await db.execute('DELETE FROM insight_decks');
  await db.execute('DELETE FROM journal_ai');
  await db.execute('DELETE FROM tag_index');
  await db.execute('DELETE FROM task_tag_index');
  await db.execute('DELETE FROM user_tag_maps');
  await db.execute('DELETE FROM user_task_tag_maps');
  await db.execute('DELETE FROM journal_entries');
  await db.execute('DELETE FROM users');
  jest.clearAllMocks();
  mockEnrichFetch();
}

async function seedCompleted(uid, id, text, createdAt) {
  await upsertUser(uid, 'T', `${uid}@t.example`);
  await upsertJournal(uid, { id, text });
  await db.execute({
    sql: `UPDATE journal_entries SET created_at = ? WHERE id = ?`,
    args: [createdAt, id],
  });
  const row = await db.execute({
    sql: `SELECT created_at FROM journal_entries WHERE id = ?`,
    args: [id],
  });
  await decks.completeDeck(uid, id, row.rows[0].created_at, CARDS(id));
}

describe('deck queue', () => {
  beforeEach(clean);

  test('rotation: sticky same day, advances daily, no binge', async () => {
    const uid = 'u-rotate';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    await seedCompleted(uid, 'j2', 'second entry text here', '2026-09-02 10:00:00');
    await seedCompleted(uid, 'j3', 'third entry text here', '2026-09-03 10:00:00');

    const d1a = await decks.getTodayDeck(uid, '2026-09-08');
    const d1b = await decks.getTodayDeck(uid, '2026-09-08');
    expect(d1a.journalId).toBe('j1');
    expect(d1b.deckId).toBe(d1a.deckId); // sticky

    // Full reveal, same day: still J1 (no binge).
    const ack = await decks.ackRevealed(uid, d1a.deckId, ['card_j1_0', 'card_j1_1', 'card_j1_2']);
    expect(ack.status).toBe('revealed');
    const d1c = await decks.getTodayDeck(uid, '2026-09-08');
    expect(d1c.deckId).toBe(d1a.deckId);

    expect((await decks.getTodayDeck(uid, '2026-09-09')).journalId).toBe('j2');
    expect((await decks.getTodayDeck(uid, '2026-09-10')).journalId).toBe('j3');
  });

  test('prefetch never marks served', async () => {
    const uid = 'u-prefetch';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    await seedCompleted(uid, 'j2', 'second entry text here', '2026-09-02 10:00:00');

    const today = await decks.getTodayDeck(uid, '2026-09-08');
    const next = await decks.getNextDeck(uid, today.deckId);
    expect(next.journalId).toBe('j2');
    const again = await decks.getTodayDeck(uid, '2026-09-08');
    expect(again.deckId).toBe(today.deckId);
  });

  test('fallback when queue empty: stable per day, rotates daily', async () => {
    const uid = 'u-fallback';
    await upsertUser(uid, 'T', `${uid}@t.example`);
    const d1a = await decks.getTodayDeck(uid, '2026-09-08');
    const d1b = await decks.getTodayDeck(uid, '2026-09-08');
    expect(d1a.fallback).toBe(true);
    expect(d1b.deckId).toBe(d1a.deckId);
    expect(d1a.insightCards.length).toBe(3);
    const d2 = await decks.getTodayDeck(uid, '2026-09-09');
    expect(d2.fallback).toBe(true);
    expect(JSON.stringify(d2.insightCards)).not.toBe(JSON.stringify(d1a.insightCards));
  });

  test('backfill: legacy journal_ai rows become servable decks', async () => {
    const uid = 'u-backfill';
    await upsertUser(uid, 'T', `${uid}@t.example`);
    const { encrypt } = require('../encryption');
    const summary = encrypt(JSON.stringify({ cards: CARDS('legacy') }), uid);
    await db.execute({
      sql: `INSERT INTO journal_entries (id, user_id, content, ai_status, created_at)
            VALUES (?, ?, ?, 'completed', '2026-09-01 10:00:00')`,
      args: ['legacy1', uid, encrypt('legacy text', uid)],
    });
    await db.execute({
      sql: `INSERT INTO journal_ai (id, journal_id, user_id, summary) VALUES (?, ?, ?, ?)`,
      args: ['ai_legacy1', 'legacy1', uid, summary],
    });
    const deck = await decks.getTodayDeck(uid, '2026-09-08');
    expect(deck.journalId).toBe('legacy1');
    expect(deck.insightCards.length).toBe(3);
  });

  test('hash guard: identical sync is no-op, edit preserves created_at', async () => {
    const uid = 'u-hash';
    await upsertUser(uid, 'T', `${uid}@t.example`);
    const r1 = await upsertJournal(uid, { id: 'j1', text: '  hello world  ' });
    expect(r1).toEqual({ isNew: true, changed: true });
    const r2 = await upsertJournal(uid, { id: 'j1', text: 'hello world' });
    expect(r2).toEqual({ isNew: false, changed: false });

    const before = await db.execute({
      sql: `SELECT created_at FROM journal_entries WHERE id = ?`, args: ['j1'],
    });
    await db.execute({
      sql: `UPDATE journal_entries SET created_at = '2026-09-01 10:00:00' WHERE id = ?`,
      args: ['j1'],
    });
    const r3 = await upsertJournal(uid, { id: 'j1', text: 'hello world EDITED here' });
    expect(r3.changed).toBe(true);
    const after = await db.execute({
      sql: `SELECT created_at, ai_status FROM journal_entries WHERE id = ?`, args: ['j1'],
    });
    expect(after.rows[0].created_at).toBe('2026-09-01 10:00:00');
    expect(after.rows[0].ai_status).toBe('pending');
    void before;
  });

  test('reveal ack: partial stays served, full flips, idempotent', async () => {
    const uid = 'u-reveal';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    const today = await decks.getTodayDeck(uid, '2026-09-08');
    const partial = await decks.ackRevealed(uid, today.deckId, ['card_j1_0']);
    expect(partial.status).toBe('served');
    expect(partial.remaining).toHaveLength(2);
    const full = await decks.ackRevealed(uid, today.deckId, ['card_j1_0', 'card_j1_1', 'card_j1_2']);
    expect(full.status).toBe('revealed');
    const again = await decks.ackRevealed(uid, today.deckId, ['card_j1_0', 'card_j1_1', 'card_j1_2']);
    expect(again.status).toBe('revealed');
  });

  test('completeDeck rejects non 3-4 card payloads without writing', async () => {
    const uid = 'u-validate';
    await upsertUser(uid, 'T', `${uid}@t.example`);
    await upsertJournal(uid, { id: 'j1', text: 'some text here' });
    await expect(decks.completeDeck(uid, 'j1', '2026-09-01 10:00:00', CARDS('x').slice(0, 2)))
      .rejects.toThrow(/3-4/);
    const rows = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE journal_id = ? AND status = 'ready'`,
      args: ['j1'],
    });
    expect(Number(rows.rows[0].n)).toBe(0);
  });

  test('concurrent serve claims exactly one deck', async () => {
    const uid = 'u-race';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    const [a, b] = await Promise.all([
      decks.getTodayDeck(uid, '2026-09-08'),
      decks.getTodayDeck(uid, '2026-09-08'),
    ]);
    expect(a.deckId).toBe(b.deckId);
    const served = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND deck_date = '2026-09-08' AND status IN ('served','revealed')`,
      args: [uid],
    });
    expect(Number(served.rows[0].n)).toBe(1);
  });

  test('per-journal status reports queue position', async () => {
    const uid = 'u-status';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    await seedCompleted(uid, 'j2', 'second entry text here', '2026-09-02 10:00:00');
    const s2 = await decks.getJournalInsight(uid, 'j2');
    expect(s2.aiStatus).toBe('pending'); // seedCompleted bypasses ai_status; decks carry readiness
    expect(s2.queuePosition).toBeGreaterThanOrEqual(1);
    expect(s2.insightCards.length).toBe(3);
  });

  test('served-edit re-queues: revealed history frozen, new deck queued', async () => {
    const uid = 'u-requeue';
    await seedCompleted(uid, 'j1', 'first entry text here', '2026-09-01 10:00:00');
    const d1 = await decks.getTodayDeck(uid, '2026-09-08');
    await decks.ackRevealed(uid, d1.deckId, ['card_j1_0', 'card_j1_1', 'card_j1_2']);
    // Real edit after reveal: old deck stays revealed, AI re-runs, new deck queues.
    await upsertJournal(uid, { id: 'j1', text: 'first entry text here EDITED a lot' });
    const j1row = await db.execute({
      sql: `SELECT created_at FROM journal_entries WHERE id = ?`, args: ['j1'],
    });
    await decks.completeDeck(uid, 'j1', j1row.rows[0].created_at, CARDS('a2'));
    // Today still shows the frozen revealed deck (no rewrite, no binge).
    const still = await decks.getTodayDeck(uid, '2026-09-08');
    expect(still.deckId).toBe(d1.deckId);
    expect(still.status).toBe('revealed');
    // Tomorrow serves the regenerated deck.
    const d2 = await decks.getTodayDeck(uid, '2026-09-09');
    expect(d2.journalId).toBe('j1');
    expect(d2.deckId).not.toBe(d1.deckId);
    expect(d2.insightCards[0].insight).toMatch(/a2/);
  });

  test('poller completes pending journals end-to-end (mocked Fanar)', async () => {
    const uid = 'u-poller';
    await upsertUser(uid, 'T', `${uid}@t.example`);
    fanar.callAI.mockResolvedValue({ cards: CARDS('ai') });
    await upsertJournal(uid, { id: 'jp', text: 'poller journal text here' });
    await pollPendingJournals();
    const st = await db.execute({
      sql: `SELECT ai_status FROM journal_entries WHERE id = ?`, args: ['jp'],
    });
    expect(st.rows[0].ai_status).toBe('completed');
    const deck = await db.execute({
      sql: `SELECT status FROM insight_decks WHERE journal_id = ? AND status = 'ready'`,
      args: ['jp'],
    });
    expect(deck.rows.length).toBe(1);
    const served = await decks.getTodayDeck(uid, '2026-09-08');
    expect(served.journalId).toBe('jp');
    expect(served.insightCards.find((c) => c.type === 'surah_guidance').arabicVerse).toBe('arabic');
  });
});

describe('deck routes (HTTP, stub auth, same temp DB)', () => {
  const request = require('supertest');
  const express = require('express');
  let app;
  const UID = 'u-http';

  function cardIds(payload) {
    return (payload.insightCards || []).map((c) => c.id);
  }

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api/v2', (req, res, next) => {
      req.uid = req.headers['x-test-uid'] || UID;
      next();
    });
    require('../routes/decks')(app);
  });

  beforeEach(async () => {
    await db.execute('DELETE FROM insight_decks');
    await db.execute('DELETE FROM journal_ai');
    await db.execute('DELETE FROM tag_index');
    await db.execute('DELETE FROM task_tag_index');
    await db.execute('DELETE FROM user_tag_maps');
    await db.execute('DELETE FROM user_task_tag_maps');
    await db.execute('DELETE FROM journal_entries');
    await db.execute('DELETE FROM users');
    jest.clearAllMocks();
    mockEnrichFetch();
    await upsertUser(UID, 'T', `${UID}@t.example`);
  });

  test('today/next/reveal/tomorrow flow over HTTP with distinct decks', async () => {
    for (const [id, text, at] of [
      ['h1', 'http journal one text', '2026-09-01 10:00:00'],
      ['h2', 'http journal two text', '2026-09-02 10:00:00'],
    ]) {
      await upsertJournal(UID, { id, text });
      const row = await db.execute({
        sql: `SELECT created_at FROM journal_entries WHERE id = ?`, args: [id],
      });
      await decks.completeDeck(UID, id, row.rows[0].created_at, CARDS(id));
    }

    const t1 = await request(app).get(`/api/v2/user/${UID}/decks/today?day=2026-09-08`);
    expect(t1.status).toBe(200);
    expect(t1.body.journalId).toBe('h1');
    expect(t1.body.insightCards).toHaveLength(3);

    const next = await request(app).get(
      `/api/v2/user/${UID}/decks/next?excludeDeckId=${t1.body.deckId}`
    );
    expect(next.status).toBe(200);
    expect(next.body.journalId).toBe('h2');

    const badReveal = await request(app)
      .post(`/api/v2/user/${UID}/decks/${t1.body.deckId}/revealed`)
      .send({ cardIds: ['card_h1_0'] });
    expect(badReveal.status).toBe(200);
    expect(badReveal.body.status).toBe('served');

    const goodReveal = await request(app)
      .post(`/api/v2/user/${UID}/decks/${t1.body.deckId}/revealed`)
      .send({ cardIds: cardIds(t1.body) });
    expect(goodReveal.body.status).toBe('revealed');

    const t2 = await request(app).get(`/api/v2/user/${UID}/decks/today?day=2026-09-09`);
    expect(t2.body.journalId).toBe('h2');
    expect(t2.body.deckId).not.toBe(t1.body.deckId);

    const status = await request(app).get('/api/v2/journal/h2/insight');
    expect(status.status).toBe(200);
    expect(status.body.deckStatus).toBe('served');

    const health = await request(app).get(`/api/v2/user/${UID}/decks/health`);
    expect(health.status).toBe(200);
    expect(health.body).toMatchObject({ ready: 0, served: 1 });
  });

  test('auth mismatch, bad body, unknown deck/journal', async () => {
    const forbidden = await request(app)
      .get('/api/v2/user/someone-else/decks/today?day=2026-09-08')
      .set('x-test-uid', UID);
    expect(forbidden.status).toBe(403);

    const badBody = await request(app)
      .post(`/api/v2/user/${UID}/decks/nope/revealed`)
      .send({ cardIds: 'not-an-array' });
    expect(badBody.status).toBe(400);

    const missing = await request(app)
      .post(`/api/v2/user/${UID}/decks/nope/revealed`)
      .send({ cardIds: [] });
    expect(missing.status).toBe(404);

    const noJournal = await request(app).get('/api/v2/journal/ghost/insight');
    expect(noJournal.status).toBe(404);
  });
});
