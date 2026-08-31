const db = require('./db');
const { setCache, getCache } = require('./cache');
const { buildInsightCardsFromRows, loadSimilarMatchesForJournal } = require('./journals');

const FETCH_TIMEOUT_MS = 5000;

function fetchWithTimeout(url, opts = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  return fetch(url, { ...opts, signal: controller.signal }).finally(() => clearTimeout(timer));
}

async function enrichSurahCard(card) {
  if (!card || card.type !== 'surah_guidance' || !card.reference) return;
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

    const audioRes = await fetchWithTimeout(
      `https://api.alquran.cloud/v1/ayah/${ayahData[0].number}/ar.alafasy`
    );
    const audioJson = audioRes.ok ? await audioRes.json() : null;

    card.arabicVerse = ayahData[0].text;
    card.transliteration = ayahData[1].text;
    card.english = ayahData[2].text;
    card.surahName = ayahData[0].surah.englishName;
    card.ayahNumber = ayahData[0].numberInSurah;
    card.audioUrl = audioJson?.data?.audio || '';
  } catch (e) {
    console.warn('[enrichSurahCard] Failed:', e.message);
  }
}

/**
 * New: 1 journal = 3 cards per deck.
 * Priority: 1) yesterday/today batch if exists, else 2) latest unread fallback (unlimited window).
 * For local-only v1, "unread" is determined client-side via excludedIds.
 * Backend handles date window + excludeIds filtering.
 */
async function buildScratchBatch(uid, { excludeIds = [], dayKeys = [] } = {}) {
  // Build cache key that includes exclude list hash to avoid cache poisoning
  const excludeKey = excludeIds.length ? `:ex:${excludeIds.join(',')}` : '';
  const dayKeyStr = dayKeys.length ? dayKeys.join(',') : 'any';
  const cacheKey = `scratch:${uid}:${dayKeyStr}${excludeKey}`;
  const cached = getCache(cacheKey);
  if (cached) return cached;

  // Helper to query with optional date filter and exclude
  async function queryBatch(whereDateSql, dateArgs) {
    let sql = `
      SELECT j.id, j.content, j.created_at, a.summary
      FROM journal_entries j
      INNER JOIN journal_ai a ON j.id = a.journal_id
      WHERE j.user_id = ? AND j.ai_status = 'completed'
    `;
    const args = [uid];
    if (whereDateSql) {
      sql += ` AND ${whereDateSql}`;
      args.push(...dateArgs);
    }
    if (excludeIds.length) {
      sql += ` AND j.id NOT IN (${excludeIds.map(() => '?').join(',')})`;
      args.push(...excludeIds);
    }
    sql += ` ORDER BY j.created_at DESC LIMIT 1`;
    const res = await db.execute({ sql, args });
    return res.rows;
  }

  // 1) Try yesterday/today window if dayKeys provided (dayKeys = [today, yesterday])
  let rows = [];
  if (dayKeys.length) {
    // Use DATE(created_at) which is UTC; also support id prefix fallback for local dates
    // We check both created_at date and id prefix for robustness
    const datePlaceholders = dayKeys.map(() => `date(j.created_at) = ?`).join(' OR ');
    const idPlaceholders = dayKeys.map(() => `j.id LIKE ?`).join(' OR ');
    const whereDateSql = `((${datePlaceholders}) OR (${idPlaceholders}))`;
    const dateArgs = [...dayKeys, ...dayKeys.map(k => `${k}%`)];
    rows = await queryBatch(whereDateSql, dateArgs);
  }

  // 2) Fallback: unlimited window, latest not excluded
  if (!rows.length) {
    rows = await queryBatch(null, []);
  }

  if (!rows.length) {
    const empty = {
      journalId: null,
      insightCards: [],
      related: { journalId: null, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
      featuredReference: null,
    };
    setCache(cacheKey, empty);
    return empty;
  }

  const insightCards = buildInsightCardsFromRows(rows, uid);
  if (!insightCards.length) {
    const empty = {
      journalId: rows[0].id,
      insightCards: [],
      related: { journalId: rows[0].id, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
      featuredReference: null,
    };
    setCache(cacheKey, empty);
    return empty;
  }

  const journalId = rows[0].id;
  const surahCard = insightCards.find(c => c.type === 'surah_guidance');
  await enrichSurahCard(surahCard).catch(() => {});

  let related = { reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] };
  try {
    related = await loadSimilarMatchesForJournal(uid, journalId);
  } catch (e) {
    console.warn('[buildScratchBatch] loadSimilarMatches failed:', e.message);
  }

  const payload = {
    journalId,
    insightCards,
    related: {
      journalId,
      reflectionTags: related.reflectionTags,
      taskTags: related.taskTags,
      similarReflections: related.similarReflections,
      similarTasks: related.similarTasks,
    },
    featuredReference: surahCard?.reference || insightCards[0]?.reference || null,
  };

  setCache(cacheKey, payload);
  return payload;
}

async function buildDailyContent(uid, dayKey) {
  const cacheKey = `daily:${uid}:${dayKey}`;
  const cached = getCache(cacheKey);
  if (cached) return cached;

  // Delegate to scratch batch for consistent priority logic
  // dayKey provided -> treat as today, also check yesterday
  let dayKeys = [];
  if (dayKey) {
    try {
      const d = new Date(dayKey);
      const y = new Date(d);
      y.setDate(d.getDate() - 1);
      const yKey = y.toISOString().slice(0, 10);
      dayKeys = [dayKey, yKey];
    } catch (_) {
      dayKeys = [dayKey];
    }
  }

  const scratch = await buildScratchBatch(uid, { excludeIds: [], dayKeys });
  if (scratch.journalId) {
    const payload = {
      dayKey,
      insightCards: scratch.insightCards,
      tasks: [],
      related: scratch.related,
      featuredReference: scratch.featuredReference,
    };
    setCache(cacheKey, payload);
    return payload;
  }

  return {
    dayKey,
    insightCards: [],
    tasks: [],
    related: { journalId: null, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
    featuredReference: null,
  };
}

module.exports = { enrichSurahCard, buildDailyContent, buildScratchBatch };
