// Partial reveal progress persists per deck and restores via getAllDecks.
// Run: npx jest tests/decks_reveal_progress.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `deckreveal-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'deck-reveal-test-secret-1234567890';

jest.mock('../services/ai', () => ({
  callAI: jest.fn(),
  callAIRaw: jest.fn(),
  callFanarRaw: jest.fn(),
  callOpenRouterRaw: jest.fn(),
  callFanar: jest.fn(),
  callOpenRouter: jest.fn(),
  parseAiJson: jest.fn((s) => JSON.parse(s)),
}));

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

const CARDS = (tag) => [
  { type: 'personalized_insight', journalExcerpt: `excerpt ${tag}`, insight: `insight ${tag}`, quote: 'q', reference: 'Quran 2:286' },
  { type: 'surah_guidance', reference: '2:286', explanation: `explanation ${tag}` },
  { type: 'story_and_task', story: `story ${tag}`, storyReference: 'Src', lesson: 'l', taskTitle: 't', taskDescription: 'd' },
];

let db;
let decks;
let upsertJournal;
let upsertUser;

beforeAll(async () => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
  mockEnrichFetch();
  const { initDB } = require('../lib/schema');
  await initDB();
  db = require('../lib/db');
  decks = require('../lib/decks');
  ({ upsertJournal } = require('../lib/journals'));
  ({ upsertUser } = require('../lib/users'));
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

test('partial acks persist; full coverage flips; getAllDecks restores', async () => {
  const uid = 'u-reveal';
  await upsertUser(uid, 'T', `${uid}@t.example`);
  await upsertJournal(uid, { id: 'j9', text: 'some journal text here' });
  await decks.completeDeck(uid, 'j9', '2026-09-08 10:00:00', CARDS('j9'));
  // Serve it so ackRevealed accepts the ack.
  const served = await decks.getTodayDeck(uid, '2026-09-08');
  expect(served.status).toBe('served');

  const partial = await decks.ackRevealed(uid, served.deckId, ['card_j9_0']);
  expect(partial.status).toBe('served');
  expect(partial.remaining.sort()).toEqual(['card_j9_1', 'card_j9_2']);

  const stored = await db.execute({
    sql: 'SELECT revealed_cards, status FROM insight_decks WHERE id = ?',
    args: [served.deckId],
  });
  expect(JSON.parse(stored.rows[0].revealed_cards)).toEqual(['card_j9_0']);
  expect(stored.rows[0].status).toBe('served');

  const full = await decks.ackRevealed(uid, served.deckId, ['card_j9_0', 'card_j9_1', 'card_j9_2']);
  expect(full.status).toBe('revealed');

  const all = await decks.getAllDecks(uid);
  const mine = all.find((d) => d.deckId === served.deckId);
  expect(mine).toBeDefined();
  expect(mine.status).toBe('revealed');
  expect([...mine.revealedCards].sort()).toEqual(['card_j9_0', 'card_j9_1', 'card_j9_2']);
});
