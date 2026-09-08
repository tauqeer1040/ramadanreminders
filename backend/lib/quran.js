const db = require('./db');
const { setCache, getCache } = require('./cache');
const { buildInsightCardsFromRows, loadSimilarMatchesForJournal } = require('./journals');

const FETCH_TIMEOUT_MS = 5000;
// Legacy scratch/daily read cache: kept short (5min) now that deck writes
// explicitly bust scratch:* via clearScratchCache. New clients use /decks/*.
const LEGACY_CACHE_TTL_MS = 5 * 60 * 1000;

// Daily-verse fallback pool: used when the user has no eligible journal
// (nothing completed yet, or everything revealed). Rotates deterministically
// by date — stable all day, fresh tomorrow. Entries mirror the normal
// 3-card schema so renderers need no changes.
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
    taskTitle: 'Return once', taskDescription: 'Make one sincere du\u2019a for the thing you gave up on.',
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

function buildDailyFallback(dateStr) {
  const dayNum = Math.floor(Date.parse(`${dateStr}T00:00:00Z`) / 86400000);
  const start = ((Number.isFinite(dayNum) ? dayNum : 0) % DAILY_VERSES.length + DAILY_VERSES.length) % DAILY_VERSES.length;
  const pick = [0, 1, 2].map((k) => DAILY_VERSES[(start + k) % DAILY_VERSES.length]);
  const journalId = `daily-${dateStr}`;
  const insightCards = [
    {
      id: `card_${journalId}_0`,
      date: dateStr,
      type: 'personalized_insight',
      journalExcerpt: 'A fresh page, a fresh mercy.',
      insight: `Today the Quran meets you where you are. "${pick[0].english}" — hold that close while you journal, and let it answer something you carried in.`,
      quote: pick[0].english,
      reference: `Quran ${pick[0].reference}`,
    },
    {
      id: `card_${journalId}_1`,
      date: dateStr,
      type: 'surah_guidance',
      reference: pick[1].reference,
      explanation: `"${pick[1].english}" Keep this verse with you today like a traveling companion — especially when things feel heavy.`,
    },
    {
      id: `card_${journalId}_2`,
      date: dateStr,
      type: 'story_and_task',
      story: pick[2].story,
      storyReference: pick[2].storyReference,
      lesson: pick[2].lesson,
      taskTitle: pick[2].taskTitle,
      taskDescription: pick[2].taskDescription,
    },
  ];
  return {
    journalId,
    insightCards,
    related: { journalId, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
    featuredReference: pick[1].reference,
    fallback: true,
  };
}

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
    // No eligible journal: daily-verse fallback (stable all day, rotates
    // tomorrow) instead of an empty deck.
    const fbDate = (dayKeys[0] || new Date().toISOString().slice(0, 10));
    const fb = buildDailyFallback(fbDate);
    setCache(cacheKey, fb, LEGACY_CACHE_TTL_MS);
    return fb;
  }

  const insightCards = buildInsightCardsFromRows(rows, uid);
  if (!insightCards.length) {
    const empty = {
      journalId: rows[0].id,
      insightCards: [],
      related: { journalId: rows[0].id, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
      featuredReference: null,
    };
    setCache(cacheKey, empty, LEGACY_CACHE_TTL_MS);
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

  setCache(cacheKey, payload, LEGACY_CACHE_TTL_MS);
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
    setCache(cacheKey, payload, LEGACY_CACHE_TTL_MS);
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
