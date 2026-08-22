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

async function buildDailyContent(uid, dayKey) {
  const cacheKey = `daily:${uid}:${dayKey}`;
  const cached = getCache(cacheKey);
  if (cached) return cached;

  const latestRowsResult = await db.execute({
    sql: `
      SELECT
        j.id,
        j.content,
        j.created_at,
        a.summary
      FROM journal_entries j
      INNER JOIN journal_ai a ON j.id = a.journal_id
      WHERE j.user_id = ? AND j.ai_status = 'completed'
      ORDER BY j.created_at DESC
      LIMIT 1
    `,
    args: [uid],
  });

  const latestRows = latestRowsResult.rows;
  if (!latestRows.length) {
    return {
      dayKey,
      insightCards: [],
      tasks: [],
      related: { journalId: null, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
      featuredReference: null,
    };
  }

  const insightCards = buildInsightCardsFromRows(latestRows, uid);
  if (!insightCards.length) return {
    dayKey, insightCards: [], tasks: [],
    related: { journalId: null, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
    featuredReference: null,
  };

  const latestJournal = latestRows[0];

  const surahCard = insightCards.find(c => c.type === 'surah_guidance');
  await enrichSurahCard(surahCard).catch(() => {});

  let related = { reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] };
  try {
    related = await loadSimilarMatchesForJournal(uid, latestJournal.id);
  } catch (e) {
    console.warn('[buildDailyContent] loadSimilarMatches failed:', e.message);
  }

  const payload = {
    dayKey,
    insightCards,
    tasks: [],
    related: {
      journalId: latestJournal.id,
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

module.exports = { enrichSurahCard, buildDailyContent };
