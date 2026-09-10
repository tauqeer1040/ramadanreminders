// Insight decks: latest-first queue, launch-drain serving (see claimNextDeck).
//
// Serve priority for GET today?day=LOCAL_DAY:
//   1. Sticky: deck already served for `day` (served|revealed) -> return it.
//   2. Unread queue: latest `ready` deck (by journal created_at DESC) -> mark
//      served with deck_date=day, return it. Covers "no journal today/yesterday
//      but unread exists".
//   3. Suggested fallback: rotation over the shared 27-verse pool
//      (lib/daily_verses), advancing per LAUNCH via the client-provided `seq`
//      (falling back to server-side deck count + day when absent). Not stored,
//      never consumes the queue. Consecutive launches share ZERO verses.
//
// Reads are cached 5min under deck:{uid}:{day} and explicitly busted on deck
// writes (complete/supersede/reveal). Never rely on TTL alone.
const crypto = require('crypto');
const db = require('./db');
const { getCache, setCache, clearDeckCache } = require('./cache');
const { sanitizeInsightCards } = require('./sanitize');
const { decrypt } = require('../encryption');
const { pickDisjointTriple, rotationIndexFor } = require('./daily_verses');

const DECK_CACHE_TTL_MS = 5 * 60 * 1000;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;


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

function buildSuggestedDeck(uid, dayKey, seq) {
  // Rotation index advances per LAUNCH (client passes a launch-scoped seq;
  // server falls back to deck count + day so calls without seq still vary
  // across days but stay stable within a session).
  const dayNum = Math.floor(Date.parse(`${dayKey}T00:00:00Z`) / 86400000) || 0;
  const k = rotationIndexFor(uid, Number.isFinite(Number(seq)) ? Number(seq) : dayNum);
  const pick = pickDisjointTriple(k);
  const journalId = `daily-${dayKey}-${k}`;
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
async function getTodayDeck(uid, dayKeyRaw, seq) {
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

  // 2) Latest unread ready deck (newest journal first → most relevant).
  const next = await db.execute({
    sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
          JOIN journal_entries j ON j.id = d.journal_id
          WHERE d.user_id = ? AND d.status = 'ready'
          ORDER BY j.created_at DESC, d.created_at DESC LIMIT 1`,
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

  // 3) Suggested fallback (not stored; rotates per launch via seq; never
  //    consumes the queue).
  return buildSuggestedDeck(uid, dayKey, seq);
}

/** Prefetch helper: latest ready deck excluding the current one. Never marks served. */
async function getNextDeck(uid, excludeDeckId) {
  let sql = `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
             JOIN journal_entries j ON j.id = d.journal_id
             WHERE d.user_id = ? AND d.status = 'ready'`;
  const args = [uid];
  if (excludeDeckId) {
    sql += ` AND d.id != ?`;
    args.push(excludeDeckId);
  }
  sql += ` ORDER BY j.created_at DESC, d.created_at DESC LIMIT 1`;
  const r = await db.execute({ sql, args });
  if (!r.rows.length) return null;
  return deckPayload(r.rows[0], { queueDepth: await getQueueDepth(uid) });
}

/**
 * Claim helper for the launch-drain: newest `ready` deck excluding the
 * current one, atomically flipped to `served` for `day` (same race-safe
 * pattern as getTodayDeck step 2). Returns the payload, or null when the
 * backlog is empty. Callers adopt the claimed deck, making it today's
 * sticky serve — launches never flip-flop back to the older deck.
 */
async function claimNextDeck(uid, excludeDeckId, dayKeyRaw, seq) {
  const dayKey = normalizeDay(dayKeyRaw);
  let sql = `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
             JOIN journal_entries j ON j.id = d.journal_id
             WHERE d.user_id = ? AND d.status = 'ready'`;
  const args = [uid];
  if (excludeDeckId) {
    sql += ` AND d.id != ?`;
    args.push(excludeDeckId);
  }
  sql += ` ORDER BY j.created_at DESC, d.created_at DESC LIMIT 1`;
  const r = await db.execute({ sql, args });
  if (!r.rows.length) return null;
  const row = r.rows[0];
  const claimed = await db.execute({
    sql: `UPDATE insight_decks SET status = 'served', deck_date = ?, served_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'ready'`,
    args: [dayKey, row.id],
  });
  if (Number(claimed.rowsAffected || 0) === 0) {
    // Lost a race with another claim/serve; backlog state changed — let the
    // caller retry (it will observe the winner via sticky /today).
    return null;
  }
  const served = await db.execute({
    sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
          JOIN journal_entries j ON j.id = d.journal_id WHERE d.id = ?`,
    args: [row.id],
  });
  // Writes bust reads: today's sticky cache must serve the claimed deck.
  try { clearDeckCache(uid); } catch (_) {}
  return deckPayload(served.rows[0], { queueDepth: await getQueueDepth(uid) });
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
    // Latest-first queue: position = how many ready decks are newer (served first).
    const pos = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM insight_decks d
            JOIN journal_entries j ON j.id = d.journal_id
            WHERE d.user_id = ? AND d.status = 'ready'
              AND (j.created_at > ? OR (j.created_at = ? AND d.created_at >= ?))`,
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

/**
 * All stored decks for a user, newest journal first (full-card payloads).
 * Backs the client-side rotation cache: the device caches every AI insight
 * once and loops through them locally, capped at 3 deck changes/day.
 * Weak decks (missing cards_json) are skipped, not fatal.
 */
async function getAllDecks(uid) {
  const rows = await db.execute({
    sql: `SELECT d.*, j.created_at AS journal_created_at FROM insight_decks d
          JOIN journal_entries j ON j.id = d.journal_id
          WHERE d.user_id = ? AND d.cards_json IS NOT NULL
          ORDER BY j.created_at DESC, d.created_at DESC
          LIMIT 200`,
    args: [uid],
  });
  return rows.rows
    .map((row) => deckPayload(row, { queueDepth: 0 }))
    .filter((p) => p.insightCards.length > 0);
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
  claimNextDeck,
  ackRevealed,
  getJournalInsight,
  getAllDecks,
  enrichSurahCard,
};
