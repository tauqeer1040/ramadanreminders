// Insight decks: 1 deck (3-4 cards) per calendar day, strict FIFO queue, no binges.
//
// Serve priority for GET today?day=LOCAL_DAY (client-local date string):
//   1. Sticky: deck already served for `day` (served|revealed) -> return it.
//   2. Unread queue: oldest `ready` deck (by journal created_at ASC) -> mark
//      served with deck_date=day, return it. Covers "no journal today/yesterday
//      but unread exists".
//   3. Suggested fallback: deterministic daily deck (not stored, never consumes
//      queue). Consumes today's slot: a journal completing later today queues
//      for tomorrow.
//
// Reads are cached 5min under deck:{uid}:{day} and explicitly busted on deck
// writes (complete/supersede/reveal). Never rely on TTL alone.
const crypto = require('crypto');
const db = require('./db');
const { getCache, setCache } = require('./cache');
const { sanitizeInsightCards } = require('./sanitize');
const { decrypt } = require('../encryption');

const DECK_CACHE_TTL_MS = 5 * 60 * 1000;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

// Duplicated from lib/quran.js DAILY_VERSES (kept local to avoid a
// journals<->quran require cycle). Keep pools in sync when editing copy.
const DAILY_VERSES = [
  {
    reference: '94:5', english: 'Indeed, with hardship comes ease.',
    story: 'The Prophet ﷺ received these words in Mecca, in some of the hardest years of his life — and ease did come.',
    storyReference: 'Surah Ash-Sharh', lesson: 'Hard seasons end; keep walking.',
    taskTitle: 'Name one ease', taskDescription: 'Write down one small ease hidden inside today.',
  },
  {
    reference: '2:286', english: 'Allah does not burden a soul beyond what it can bear.',
    story: 'Prophet Yunus, alone in the belly of the whale, in total darkness — and even that was not beyond bearing.',
    storyReference: 'Surah Al-Anbiya', lesson: 'You were built for this weight.',
    taskTitle: 'Carry one thing', taskDescription: 'Pick the single heaviest task today and do just that one.',
  },
  {
    reference: '39:53', english: 'Do not despair of the mercy of Allah.',
    story: 'Musa stood before the sea with an army behind him — and the sea split.',
    storyReference: 'Surah Az-Zumar', lesson: 'No dead end is final with Allah.',
    taskTitle: 'Return once', taskDescription: 'Make one sincere du’a for the thing you gave up on.',
  },
  {
    reference: '65:3', english: 'And whoever relies upon Allah — He is sufficient for them.',
    story: 'Hajar ran between Safa and Marwa with a crying infant — and Zamzam burst forth where she least expected.',
    storyReference: 'Surah At-Talaq', lesson: 'Effort plus trust opens doors.',
    taskTitle: 'Delegate one worry', taskDescription: 'Hand one worry to Allah today and act on what you can.',
  },
  {
    reference: '3:139', english: 'Do not lose heart, nor grieve — you will be superior, if you are believers.',
    story: 'After the losses at Uhud, the believers were told not to grieve — and they rose again.',
    storyReference: 'Surah Aal-Imran', lesson: 'Setbacks are chapters, not endings.',
    taskTitle: 'Reframe one loss', taskDescription: 'Write what one recent setback taught you.',
  },
  {
    reference: '2:152', english: 'So remember Me; I will remember you.',
    story: 'Maryam, alone in childbirth pain, was told to shake the palm tree — remembrance met provision.',
    storyReference: 'Surah Al-Baqarah', lesson: 'One remembrance is never one-sided.',
    taskTitle: 'Remember once', taskDescription: 'Say one dhikr slowly, meaning every word.',
  },
  {
    reference: '13:28', english: 'Verily, in the remembrance of Allah do hearts find rest.',
    story: 'Yusuf, betrayed and imprisoned for years, kept a tranquil heart — and walked out to honor.',
    storyReference: 'Surah Ar-Ra’d', lesson: 'Calm is a practice, not a place.',
    taskTitle: 'Two quiet minutes', taskDescription: 'Sit still for two minutes and remember Allah.',
  },
  {
    reference: '20:114', english: 'My Lord, increase me in knowledge.',
    story: 'Musa traveled far simply to learn from Khidr — knowledge was worth the journey.',
    storyReference: 'Surah Ta-Ha', lesson: 'Keep learning, one verse at a time.',
    taskTitle: 'Learn one ayah', taskDescription: 'Read one ayah with its meaning today.',
  },
  {
    reference: '55:13', english: 'So which of the favors of your Lord would you deny?',
    story: 'Ibrahim was thrown into fire for his faith — and the fire was made cool and safe for him.',
    storyReference: 'Surah Ar-Rahman', lesson: 'Count favors before fears.',
    taskTitle: 'List three favors', taskDescription: 'Write three blessings you used today.',
  },
];

function contentHash(text) {
  return crypto.createHash('sha256').update(String(text || '').trim(), 'utf8').digest('hex');
}

function normalizeDay(day) {
  const s = String(day || '').slice(0, 10);
  if (DAY_RE.test(s)) return s;
  return new Date().toISOString().slice(0, 10);
}

function newDeckId(journalId) {
  const rand = crypto.randomBytes(4).toString('hex');
  return `deck_${journalId}_${Date.now().toString(36)}${rand}`;
}

function parseCards(row) {
  try {
    const cards = JSON.parse(row.cards_json || '[]');
    return Array.isArray(cards) ? cards : [];
  } catch (_) {
    return [];
  }
}

function deckPayload(row, { fallback = false, queueDepth = 0 } = {}) {
  const cards = parseCards(row);
  const surahCard = cards.find((c) => c && c.type === 'surah_guidance');
  return {
    deckId: row.id,
    journalId: row.journal_id,
    deckDate: row.deck_date,
    status: row.status,
    insightCards: cards,
    related: { journalId: row.journal_id, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
    featuredReference: (surahCard && surahCard.reference) || (cards[0] && (cards[0].reference || null)) || null,
    queueDepth,
    fallback,
  };
}

function buildSuggestedDeck(dayKey) {
  const dayNum = Math.floor(Date.parse(`${dayKey}T00:00:00Z`) / 86400000);
  const len = DAILY_VERSES.length;
  const start = ((Number.isFinite(dayNum) ? dayNum : 0) % len + len) % len;
  const pick = [0, 1, 2].map((k) => DAILY_VERSES[(start + k) % len]);
  const journalId = `daily-${dayKey}`;
  const insightCards = [
    {
      id: `card_${journalId}_0`,
      date: dayKey,
      type: 'personalized_insight',
      journalExcerpt: 'A fresh page, a fresh mercy.',
      insight: `Today the Quran meets you where you are. "${pick[0].english}" — hold that close while you journal, and let it answer something you carried in.`,
      quote: pick[0].english,
      reference: `Quran ${pick[0].reference}`,
    },
    {
      id: `card_${journalId}_1`,
      date: dayKey,
      type: 'surah_guidance',
      reference: pick[1].reference,
      explanation: `"${pick[1].english}" Keep this verse with you today like a traveling companion — especially when things feel heavy.`,
    },
    {
      id: `card_${journalId}_2`,
      date: dayKey,
      type: 'story_and_task',
      story: pick[2].story,
      storyReference: pick[2].storyReference,
      lesson: pick[2].lesson,
      taskTitle: pick[2].taskTitle,
      taskDescription: pick[2].taskDescription,
    },
  ];
  const surahCard = insightCards[1];
  return {
    deckId: journalId,
    journalId,
    deckDate: dayKey,
    status: 'suggested',
    insightCards,
    related: { journalId, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
    featuredReference: surahCard.reference,
    queueDepth: 0,
    fallback: true,
  };
}

async function getQueueDepth(uid) {
  const r = await db.execute({
    sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND status = 'ready'`,
    args: [uid],
  });
  return Number(r.rows[0]?.n || 0);
}

/** Mark superseded any active (unrevealed) decks for a journal. Revealed history is frozen. */
async function supersedeActiveDecks(journalId) {
  await db.execute({
    sql: `UPDATE insight_decks SET status = 'superseded', updated_at = CURRENT_TIMESTAMP
          WHERE journal_id = ? AND status IN ('building', 'ready', 'served')`,
    args: [journalId],
  });
}

/** Idempotent: ensure a building deck exists for a journal awaiting AI. */
async function ensureBuildingDeck(uid, journalId) {
  const existing = await db.execute({
    sql: `SELECT id FROM insight_decks WHERE journal_id = ? AND status IN ('building', 'ready', 'served') LIMIT 1`,
    args: [journalId],
  });
  if (existing.rows.length) return existing.rows[0].id;
  const id = newDeckId(journalId);
  await db.execute({
    sql: `INSERT INTO insight_decks (id, user_id, journal_id, status) VALUES (?, ?, ?, 'building')`,
    args: [id, uid, journalId],
  });
  return id;
}

/**
 * Complete a deck for a journal: validates 3-4 cards, assigns stable card ids,
 * supersedes prior active decks (revealed history frozen), inserts ready deck.
 */
async function completeDeck(uid, journalId, journalCreatedAt, rawCards) {
  const clean = sanitizeInsightCards(Array.isArray(rawCards) ? rawCards : []);
  if (clean.length < 3 || clean.length > 4) {
    throw new Error(`Expected 3-4 insight cards, got ${clean.length}`);
  }
  const dateStr = String(journalCreatedAt || new Date().toISOString()).slice(0, 10);
  const cards = clean.map((card, i) => ({
    id: `card_${journalId}_${i}`,
    date: journalCreatedAt || new Date().toISOString(),
    ...card,
  }));
  void dateStr;
  await supersedeActiveDecks(journalId);
  const id = newDeckId(journalId);
  await db.execute({
    sql: `INSERT INTO insight_decks (id, user_id, journal_id, status, cards_json, updated_at)
          VALUES (?, ?, ?, 'ready', ?, CURRENT_TIMESTAMP)`,
    args: [id, uid, journalId, JSON.stringify(cards)],
  });
  return { deckId: id, cards };
}

/**
 * Lazy backfill: journals completed before decks existed (or via the legacy
 * scratch path) get a ready deck so the queue works for existing users.
 * Capped per call to bound serve latency.
 */
async function backfillReadyDecks(uid, limit = 20) {
  const missing = await db.execute({
    sql: `SELECT j.id, j.created_at, a.summary FROM journal_entries j
          JOIN journal_ai a ON a.journal_id = j.id
          WHERE j.user_id = ? AND j.ai_status = 'completed'
            AND NOT EXISTS (SELECT 1 FROM insight_decks d WHERE d.journal_id = j.id AND d.status != 'superseded')
          ORDER BY j.created_at ASC LIMIT ?`,
    args: [uid, Math.min(Math.max(Number(limit) || 20, 1), 50)],
  });
  for (const row of missing.rows) {
    try {
      const decrypted = decrypt(row.summary, uid);
      const parsed = JSON.parse(decrypted);
      const rawCards = Array.isArray(parsed?.cards) ? parsed.cards : null;
      if (!rawCards || rawCards.length < 3) continue;
      await completeDeck(uid, row.id, row.created_at, rawCards);
    } catch (e) {
      console.warn('[decks.backfill] skip', row.id, e.message);
    }
  }
}

/** Serve today's deck: sticky served -> oldest ready (mark served) -> suggested fallback. */
async function getTodayDeck(uid, dayKeyRaw) {
  const dayKey = normalizeDay(dayKeyRaw);
  const cacheKey = `deck:${uid}:${dayKey}`;
  const cached = getCache(cacheKey);
  if (cached) return cached;
  try {
    await backfillReadyDecks(uid);
  } catch (_) {}

  // 1) Sticky: already served for this local day (served or revealed — no binge).
  const sticky = await db.execute({
    sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
          JOIN journal_entries j ON j.id = d.journal_id
          WHERE d.user_id = ? AND d.deck_date = ? AND d.status IN ('served', 'revealed')
          ORDER BY d.served_at DESC LIMIT 1`,
    args: [uid, dayKey],
  });
  if (sticky.rows.length) {
    const payload = deckPayload(sticky.rows[0], { queueDepth: await getQueueDepth(uid) });
    setCache(cacheKey, payload, DECK_CACHE_TTL_MS);
    return payload;
  }

  // 2) Oldest unread ready deck (FIFO by original journal time → stable queue).
  const next = await db.execute({
    sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
          JOIN journal_entries j ON j.id = d.journal_id
          WHERE d.user_id = ? AND d.status = 'ready'
          ORDER BY j.created_at ASC, d.created_at ASC LIMIT 1`,
    args: [uid],
  });
  if (next.rows.length) {
    const row = next.rows[0];
    const claimed = await db.execute({
      sql: `UPDATE insight_decks SET status = 'served', deck_date = ?, served_at = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'ready'`,
      args: [dayKey, row.id],
    });
    if (Number(claimed.rowsAffected || 0) === 0) {
      // Lost a race with another serve; re-read sticky path once.
      const retry = await db.execute({
        sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
              JOIN journal_entries j ON j.id = d.journal_id
              WHERE d.user_id = ? AND d.deck_date = ? AND d.status IN ('served', 'revealed')
              ORDER BY d.served_at DESC LIMIT 1`,
        args: [uid, dayKey],
      });
      if (retry.rows.length) {
        const payload = deckPayload(retry.rows[0], { queueDepth: await getQueueDepth(uid) });
        setCache(cacheKey, payload, DECK_CACHE_TTL_MS);
        return payload;
      }
    }
    const served = await db.execute({
      sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
            JOIN journal_entries j ON j.id = d.journal_id WHERE d.id = ?`,
      args: [row.id],
    });
    const payload = deckPayload(served.rows[0], { queueDepth: await getQueueDepth(uid) });
    setCache(cacheKey, payload, DECK_CACHE_TTL_MS);
    return payload;
  }

  // 3) Suggested fallback (not stored; stable per day; consumes today's slot).
  return buildSuggestedDeck(dayKey);
}

/** Prefetch helper: oldest ready deck excluding the current one. Never marks served. */
async function getNextDeck(uid, excludeDeckId) {
  let sql = `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
             JOIN journal_entries j ON j.id = d.journal_id
             WHERE d.user_id = ? AND d.status = 'ready'`;
  const args = [uid];
  if (excludeDeckId) {
    sql += ` AND d.id != ?`;
    args.push(excludeDeckId);
  }
  sql += ` ORDER BY j.created_at ASC, d.created_at ASC LIMIT 1`;
  const r = await db.execute({ sql, args });
  if (!r.rows.length) return null;
  return deckPayload(r.rows[0], { queueDepth: await getQueueDepth(uid) });
}

/** Idempotent reveal ack: only full-card-set coverage flips served -> revealed. */
async function ackRevealed(uid, deckId, cardIds) {
  const r = await db.execute({
    sql: `SELECT * FROM insight_decks WHERE id = ?`,
    args: [deckId],
  });
  if (!r.rows.length) {
    const err = new Error('Deck not found');
    err.statusCode = 404;
    throw err;
  }
  const row = r.rows[0];
  if (row.user_id !== uid) {
    const err = new Error('Forbidden');
    err.statusCode = 403;
    throw err;
  }
  if (row.status === 'revealed') {
    return { deckId: row.id, status: 'revealed', queueDepth: await getQueueDepth(uid) };
  }
  if (row.status !== 'served') {
    return { deckId: row.id, status: row.status, queueDepth: await getQueueDepth(uid) };
  }
  const cards = parseCards(row);
  const expected = new Set(cards.map((c) => c && c.id).filter(Boolean));
  const provided = new Set((Array.isArray(cardIds) ? cardIds : []).map(String));
  const covered = [...expected].every((id) => provided.has(id));
  if (!covered) {
    const remaining = [...expected].filter((id) => !provided.has(id));
    return { deckId: row.id, status: row.status, remaining, queueDepth: await getQueueDepth(uid) };
  }
  await db.execute({
    sql: `UPDATE insight_decks SET status = 'revealed', revealed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'served'`,
    args: [deckId],
  });
  return { deckId, status: 'revealed', queueDepth: await getQueueDepth(uid) };
}

/** Per-journal status for editor/history pending UI + queue position. */
async function getJournalInsight(uid, journalId) {
  const j = await db.execute({
    sql: `SELECT id, user_id, created_at, ai_status, ai_attempts, ai_last_error FROM journal_entries WHERE id = ?`,
    args: [journalId],
  });
  if (!j.rows.length) {
    const err = new Error('Journal not found');
    err.statusCode = 404;
    throw err;
  }
  const journal = j.rows[0];
  if (journal.user_id !== uid) {
    const err = new Error('Forbidden');
    err.statusCode = 403;
    throw err;
  }
  const d = await db.execute({
    sql: `SELECT * FROM insight_decks WHERE journal_id = ? AND status != 'superseded'
          ORDER BY CASE status WHEN 'revealed' THEN 0 WHEN 'served' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,
                   created_at DESC LIMIT 1`,
    args: [journalId],
  });
  const deck = d.rows[0] || null;
  let queuePosition = 0;
  if (deck && deck.status === 'ready') {
    const pos = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM insight_decks d
            JOIN journal_entries j ON j.id = d.journal_id
            WHERE d.user_id = ? AND d.status = 'ready'
              AND (j.created_at < ? OR (j.created_at = ? AND d.created_at <= ?))`,
      args: [uid, journal.created_at, journal.created_at, deck.created_at],
    });
    queuePosition = Number(pos.rows[0]?.n || 0);
  }
  return {
    journalId,
    aiStatus: journal.ai_status,
    aiAttempts: journal.ai_attempts,
    aiLastError: journal.ai_last_error,
    deckId: deck ? deck.id : null,
    deckStatus: deck ? deck.status : null,
    deckDate: deck ? deck.deck_date : null,
    queuePosition,
    insightCards: deck && deck.cards_json ? parseCards(deck) : [],
  };
}

const FETCH_TIMEOUT_MS = 5000;

function fetchWithTimeout(url, opts = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  return fetch(url, { ...opts, signal: controller.signal }).finally(() => clearTimeout(timer));
}

/** Pre-enrich a surah_guidance card in place (best-effort; never throws). */
async function enrichSurahCard(card) {
  if (!card || card.type !== 'surah_guidance' || !card.reference) return;
  if (card.arabicVerse && card.english) return; // already enriched
  try {
    const match = String(card.reference).match(/(\d+)[\s:]+(\d+)/);
    if (!match) return;
    const ayahKey = `${match[1]}:${match[2]}`;
    const textRes = await fetchWithTimeout(
      `https://api.alquran.cloud/v1/ayah/${ayahKey}/editions/quran-uthmani,en.transliteration,en.sahih`
    );
    if (!textRes.ok) return;
    const textJson = await textRes.json();
    const ayahData = textJson.data;
    let audioUrl = '';
    try {
      const audioRes = await fetchWithTimeout(
        `https://api.alquran.cloud/v1/ayah/${ayahData[0].number}/ar.alafasy`
      );
      if (audioRes.ok) {
        const audioJson = await audioRes.json();
        audioUrl = audioJson?.data?.audio || '';
      }
    } catch (_) {}
    card.arabicVerse = ayahData[0].text;
    card.transliteration = ayahData[1].text;
    card.english = ayahData[2].text;
    card.surahName = ayahData[0].surah.englishName;
    card.ayahNumber = ayahData[0].numberInSurah;
    card.audioUrl = audioUrl;
  } catch (e) {
    console.warn('[decks.enrichSurahCard] Failed:', e.message);
  }
}

module.exports = {
  contentHash,
  normalizeDay,
  buildSuggestedDeck,
  getQueueDepth,
  supersedeActiveDecks,
  ensureBuildingDeck,
  completeDeck,
  getTodayDeck,
  getNextDeck,
  ackRevealed,
  getJournalInsight,
  enrichSurahCard,
};
