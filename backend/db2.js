require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { createClient } = require('@libsql/client');

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.url}`);
  next();
});

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN,
});

const LM_STUDIO_BASE_URL = process.env.LM_STUDIO_BASE_URL || 'http://192.168.1.4:1234';
const LM_STUDIO_MODEL = process.env.LM_STUDIO_MODEL || 'fanar-1-9b-instruct';
const AI_PROVIDER = process.env.AI_PROVIDER || 'lmstudio';
const FANAR_BASE_URL = process.env.FANAR_BASE_URL || 'https://api.fanar.qa';
const FANAR_API_KEY = process.env.FANAR_API_KEY || '';
const FANAR_MODEL = process.env.FANAR_MODEL || 'Fanar';
const AI_INITIAL_DELAY_HOURS = Math.max(0, Number(process.env.AI_INITIAL_DELAY_HOURS || 12));
const AI_POLL_INTERVAL_MS = Math.max(5000, Number(process.env.AI_POLL_INTERVAL_MS || 60000));

const cache = new Map();
const CACHE_TTL = 3600 * 1000;

function setCache(key, value) {
  cache.set(key, { value, expiry: Date.now() + CACHE_TTL });
}

function getCache(key) {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  return item.value;
}

function clearUserCache(uid) {
  cache.delete(`user:${uid}`);
  for (const key of cache.keys()) {
    if (key.startsWith(`daily:${uid}:`)) {
      cache.delete(key);
    }
  }
}

function clearJournalCache(id) {
  cache.delete(`journal:${id}`);
}

function normalizeTag(tag) {
  return String(tag || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

async function tableExists(name) {
  const result = await db.execute({
    sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function getColumns(tableName) {
  if (!(await tableExists(tableName))) return [];
  const result = await db.execute(`PRAGMA table_info(${tableName})`);
  return result.rows.map((row) => row.name);
}

async function hasColumn(tableName, columnName) {
  const columns = await getColumns(tableName);
  return columns.includes(columnName);
}

async function getForeignKeyTargets(tableName) {
  if (!(await tableExists(tableName))) return [];
  const result = await db.execute(`PRAGMA foreign_key_list(${tableName})`);
  return result.rows.map((row) => row.table);
}

async function ensureUserTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT,
      email TEXT,
      fcm_token TEXT,
      journal_count INTEGER DEFAULT 0,
      relevant_tags TEXT DEFAULT '[]',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_active DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  if (!(await hasColumn('users', 'fcm_token'))) {
    await db.execute("ALTER TABLE users ADD COLUMN fcm_token TEXT");
  }
}

async function ensureJournalTables() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS journal_entries (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      ai_status TEXT DEFAULT 'pending',
      ai_attempts INTEGER DEFAULT 0,
      ai_last_error TEXT,
      ai_next_retry_at DATETIME,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  if (!(await hasColumn('journal_entries', 'ai_attempts'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_attempts INTEGER DEFAULT 0');
  }
  if (!(await hasColumn('journal_entries', 'ai_last_error'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_last_error TEXT');
  }
  if (!(await hasColumn('journal_entries', 'ai_next_retry_at'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_next_retry_at DATETIME');
  }

  // Backfill from the legacy table if it exists.
  if (await tableExists('journals')) {
    await db.execute(`
      INSERT OR IGNORE INTO journal_entries (id, user_id, content, created_at, ai_status)
      SELECT id, user_id, content, created_at, COALESCE(ai_status, 'pending')
      FROM journals
    `);
  }
}

async function ensureJournalAiTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS journal_ai (
      id TEXT PRIMARY KEY,
      journal_id TEXT NOT NULL UNIQUE,
      user_id TEXT NOT NULL,
      summary TEXT,
      tags TEXT DEFAULT '[]',
      quote TEXT,
      reference TEXT,
      suggested_tasks TEXT DEFAULT '[]',
      task_tags TEXT DEFAULT '[]',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  if (!(await hasColumn('journal_ai', 'suggested_tasks'))) {
    await db.execute("ALTER TABLE journal_ai ADD COLUMN suggested_tasks TEXT DEFAULT '[]'");
  }
  if (!(await hasColumn('journal_ai', 'task_tags'))) {
    await db.execute("ALTER TABLE journal_ai ADD COLUMN task_tags TEXT DEFAULT '[]'");
  }
}

async function recreateIndexTable(tableName) {
  const backupName = `${tableName}_legacy`;
  if (await tableExists(backupName)) {
    await db.execute(`DROP TABLE ${backupName}`);
  }

  if (await tableExists(tableName)) {
    await db.execute(`ALTER TABLE ${tableName} RENAME TO ${backupName}`);
  }

  await db.execute(`
    CREATE TABLE ${tableName} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      tag TEXT NOT NULL,
      journal_id TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE,
      UNIQUE(user_id, tag, journal_id)
    )
  `);

  if (await tableExists(backupName)) {
    await db.execute(`
      INSERT OR IGNORE INTO ${tableName} (user_id, tag, journal_id)
      SELECT legacy.user_id, legacy.tag, legacy.journal_id
      FROM ${backupName} AS legacy
      INNER JOIN journal_entries AS journal_entries
        ON journal_entries.id = legacy.journal_id
    `);
    await db.execute(`DROP TABLE ${backupName}`);
  }
}

async function ensureIndexTables() {
  const tagTargets = await getForeignKeyTargets('tag_index');
  const taskTagTargets = await getForeignKeyTargets('task_tag_index');

  if (!(await tableExists('tag_index')) || !tagTargets.includes('journal_entries')) {
    await recreateIndexTable('tag_index');
  }

  if (!(await tableExists('task_tag_index')) || !taskTagTargets.includes('journal_entries')) {
    await recreateIndexTable('task_tag_index');
  }

  await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_user ON journal_entries(user_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_index_user_tag ON tag_index(user_id, tag)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_task_tag_index_user_tag ON task_tag_index(user_id, tag)');
}

async function ensureTagMapTables() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS user_tag_maps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      tag TEXT NOT NULL,
      journal_ids TEXT DEFAULT '[]',
      journal_refs TEXT DEFAULT '[]',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, tag)
    )
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS user_task_tag_maps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      tag TEXT NOT NULL,
      journal_ids TEXT DEFAULT '[]',
      journal_refs TEXT DEFAULT '[]',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, tag)
    )
  `);

  if (!(await hasColumn('user_tag_maps', 'journal_refs'))) {
    await db.execute("ALTER TABLE user_tag_maps ADD COLUMN journal_refs TEXT DEFAULT '[]'");
  }
  if (!(await hasColumn('user_task_tag_maps', 'journal_refs'))) {
    await db.execute("ALTER TABLE user_task_tag_maps ADD COLUMN journal_refs TEXT DEFAULT '[]'");
  }

  await db.execute('CREATE INDEX IF NOT EXISTS idx_user_tag_maps_user_tag ON user_tag_maps(user_id, tag)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_user_task_tag_maps_user_tag ON user_task_tag_maps(user_id, tag)');
}

async function rebuildTagMapsFromIndexes() {
  await db.execute('DELETE FROM user_tag_maps');
  await db.execute('DELETE FROM user_task_tag_maps');

  const reflectionRows = await db.execute(`
    SELECT i.user_id, i.tag, i.journal_id, j.created_at
    FROM tag_index i
    INNER JOIN journal_entries j ON j.id = i.journal_id
    ORDER BY i.user_id ASC, i.tag ASC, i.journal_id ASC
  `);
  for (const row of reflectionRows.rows) {
    await upsertTagMapRow('user_tag_maps', row.user_id, row.tag, row.journal_id, row.created_at);
  }

  const taskRows = await db.execute(`
    SELECT i.user_id, i.tag, i.journal_id, j.created_at
    FROM task_tag_index i
    INNER JOIN journal_entries j ON j.id = i.journal_id
    ORDER BY i.user_id ASC, i.tag ASC, i.journal_id ASC
  `);
  for (const row of taskRows.rows) {
    await upsertTagMapRow('user_task_tag_maps', row.user_id, row.tag, row.journal_id, row.created_at);
  }
}

function getInitialAiScheduleSql() {
  if (AI_INITIAL_DELAY_HOURS <= 0) {
    return 'CURRENT_TIMESTAMP';
  }
  return `DATETIME('now', '+${AI_INITIAL_DELAY_HOURS} hours')`;
}

async function upsertTagMapRow(tableName, userId, tag, journalId, journalDate) {
  const existing = await db.execute({
    sql: `SELECT journal_ids, journal_refs FROM ${tableName} WHERE user_id = ? AND tag = ?`,
    args: [userId, tag],
  });

  const ids = existing.rows.length > 0
    ? JSON.parse(existing.rows[0].journal_ids || '[]')
    : [];
  const refs = existing.rows.length > 0
    ? JSON.parse(existing.rows[0].journal_refs || '[]')
    : [];
  const merged = Array.from(new Set([...ids, journalId]));
  const mergedRefs = [
    ...refs.filter((entry) => entry?.id !== journalId),
    { id: journalId, date: journalDate || null },
  ].sort((left, right) => String(right?.date || '').localeCompare(String(left?.date || '')));

  await db.execute({
    sql: `
      INSERT INTO ${tableName} (user_id, tag, journal_ids, journal_refs, updated_at)
      VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, tag) DO UPDATE SET
        journal_ids = excluded.journal_ids,
        journal_refs = excluded.journal_refs,
        updated_at = CURRENT_TIMESTAMP
    `,
    args: [userId, tag, JSON.stringify(merged), JSON.stringify(mergedRefs)],
  });
}

async function removeJournalFromTagMap(tableName, userId, tag, journalId) {
  const existing = await db.execute({
    sql: `SELECT journal_ids, journal_refs FROM ${tableName} WHERE user_id = ? AND tag = ?`,
    args: [userId, tag],
  });

  if (!existing.rows.length) {
    return;
  }

  const remaining = JSON.parse(existing.rows[0].journal_ids || '[]').filter((id) => id !== journalId);
  const remainingRefs = JSON.parse(existing.rows[0].journal_refs || '[]').filter((entry) => entry?.id !== journalId);
  if (remaining.length === 0) {
    await db.execute({
      sql: `DELETE FROM ${tableName} WHERE user_id = ? AND tag = ?`,
      args: [userId, tag],
    });
    return;
  }

  await db.execute({
    sql: `UPDATE ${tableName} SET journal_ids = ?, journal_refs = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND tag = ?`,
    args: [JSON.stringify(remaining), JSON.stringify(remainingRefs), userId, tag],
  });
}

async function recalculateUserMetadata(uid) {
  const journalCountResult = await db.execute({
    sql: 'SELECT COUNT(*) AS count FROM journal_entries WHERE user_id = ?',
    args: [uid],
  });
  const journalCount = Number(journalCountResult.rows[0]?.count || 0);

  const tagResult = await db.execute({
    sql: `
      SELECT tag FROM user_tag_maps WHERE user_id = ?
      UNION
      SELECT tag FROM user_task_tag_maps WHERE user_id = ?
    `,
    args: [uid, uid],
  });
  const relevantTags = tagResult.rows.map((row) => row.tag).filter(Boolean).slice(0, 20);

  await db.execute({
    sql: `
      UPDATE users
      SET journal_count = ?, relevant_tags = ?, last_active = CURRENT_TIMESTAMP
      WHERE id = ?
    `,
    args: [journalCount, JSON.stringify(relevantTags), uid],
  });
}

function normalizeTaskContent(task) {
  return String(task?.title || task?.description || '').trim().toLowerCase();
}

function buildInsightCardsFromRows(rows, limit = 3) {
  const cards = [];
  const seenRefs = new Set();
  const seenSummaries = new Set();
  const seenPrimaryTags = new Set();

  for (const row of rows) {
    if (!row.summary) continue;
    const tags = JSON.parse(row.tags || '[]');
    const primaryTag = String(tags[0] || '').trim().toLowerCase();
    const reference = String(row.reference || '').trim().toLowerCase();
    const summary = String(row.summary || '').trim().toLowerCase();

    if (
      (reference && seenRefs.has(reference)) ||
      (summary && seenSummaries.has(summary)) ||
      (primaryTag && seenPrimaryTags.has(primaryTag))
    ) {
      continue;
    }

    cards.push({
      id: row.id,
      date: row.created_at,
      greeting: tags.length > 0 ? `Reflection on ${String(tags[0]).replace(/_/g, ' ')}` : 'Deep Reflection',
      insight: row.summary,
      quote: row.quote || 'SubhanAllah',
      reference: row.reference || "Qur'an",
      tags,
    });

    if (reference) seenRefs.add(reference);
    if (summary) seenSummaries.add(summary);
    if (primaryTag) seenPrimaryTags.add(primaryTag);
    if (cards.length >= limit) break;
  }

  return cards;
}

async function loadSimilarMatchesForJournal(userId, journalId) {
  const [reflectionTags, taskTags] = await Promise.all([
    db.execute({
      sql: 'SELECT tag FROM tag_index WHERE user_id = ? AND journal_id = ? ORDER BY tag ASC',
      args: [userId, journalId],
    }),
    db.execute({
      sql: 'SELECT tag FROM task_tag_index WHERE user_id = ? AND journal_id = ? ORDER BY tag ASC',
      args: [userId, journalId],
    }),
  ]);

  const loadMatches = async (tableName, tagsResult) => {
    const refsById = new Map();
    for (const tagRow of tagsResult.rows) {
      const mapRow = await db.execute({
        sql: `SELECT journal_refs FROM ${tableName} WHERE user_id = ? AND tag = ?`,
        args: [userId, tagRow.tag],
      });
      if (!mapRow.rows.length) continue;
      const refs = JSON.parse(mapRow.rows[0].journal_refs || '[]');
      for (const ref of refs) {
        if (!ref?.id || ref.id === journalId) continue;
        const entry = refsById.get(ref.id) || { id: ref.id, date: ref.date || null, matchedTags: [] };
        entry.matchedTags = Array.from(new Set([...entry.matchedTags, tagRow.tag]));
        refsById.set(ref.id, entry);
      }
    }
    return Array.from(refsById.values()).sort((left, right) => right.matchedTags.length - left.matchedTags.length);
  };

  const [similarReflections, similarTasks] = await Promise.all([
    loadMatches('user_tag_maps', reflectionTags),
    loadMatches('user_task_tag_maps', taskTags),
  ]);

  return {
    reflectionTags: reflectionTags.rows.map((row) => row.tag),
    taskTags: taskTags.rows.map((row) => row.tag),
    similarReflections,
    similarTasks,
  };
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
        a.summary,
        a.tags,
        a.quote,
        a.reference,
        a.suggested_tasks,
        a.task_tags
      FROM journal_entries j
      INNER JOIN journal_ai a ON j.id = a.journal_id
      WHERE j.user_id = ? AND j.ai_status = 'completed'
      ORDER BY j.created_at DESC
      LIMIT 6
    `,
    args: [uid],
  });

  const latestRows = latestRowsResult.rows;
  if (!latestRows.length) {
    const empty = {
      dayKey,
      insightCards: [],
      tasks: [],
      related: { journalId: null, reflectionTags: [], taskTags: [], similarReflections: [], similarTasks: [] },
      featuredReference: null,
    };
    setCache(cacheKey, empty);
    return empty;
  }

  const insightCards = buildInsightCardsFromRows(latestRows, 3);
  const latestJournal = latestRows[0];
  const related = await loadSimilarMatchesForJournal(uid, latestJournal.id);

  const taskMap = new Map();
  const directTasks = JSON.parse(latestJournal.suggested_tasks || '[]');
  for (const task of directTasks) {
    const normalized = normalizeTaskContent(task);
    if (!normalized || taskMap.has(normalized)) continue;
    taskMap.set(normalized, {
      id: `ai_${latestJournal.id}_${taskMap.size}`,
      content: task.title || task.description || 'Ramadan Task',
      difficulty: taskMap.size === 0 ? 'easy' : taskMap.size === 1 ? 'mid' : 'hard',
      sourceJournalId: latestJournal.id,
    });
    if (taskMap.size >= 3) break;
  }

  const similarIds = Array.from(
    new Set(
      [...related.similarTasks, ...related.similarReflections]
        .map((entry) => entry.id)
        .filter(Boolean)
    )
  ).slice(0, 3);

  if (taskMap.size < 3 && similarIds.length > 0) {
    const placeholders = similarIds.map(() => '?').join(', ');
    const similarRowsResult = await db.execute({
      sql: `
        SELECT
          j.id,
          j.created_at,
          a.suggested_tasks
        FROM journal_entries j
        INNER JOIN journal_ai a ON j.id = a.journal_id
        WHERE j.user_id = ? AND j.id IN (${placeholders})
      `,
      args: [uid, ...similarIds],
    });

    for (const row of similarRowsResult.rows) {
      const tasks = JSON.parse(row.suggested_tasks || '[]');
      for (const task of tasks) {
        if (taskMap.size >= 3) break;
        const normalized = normalizeTaskContent(task);
        if (!normalized || taskMap.has(normalized)) continue;
        taskMap.set(normalized, {
          id: `ai_${row.id}_${taskMap.size}`,
          content: task.title || task.description || 'Ramadan Task',
          difficulty: taskMap.size === 0 ? 'easy' : taskMap.size === 1 ? 'mid' : 'hard',
          sourceJournalId: row.id,
        });
      }
    }
  }

  const payload = {
    dayKey,
    insightCards,
    tasks: Array.from(taskMap.values()),
    related: {
      journalId: latestJournal.id,
      reflectionTags: related.reflectionTags,
      taskTags: related.taskTags,
      similarReflections: related.similarReflections,
      similarTasks: related.similarTasks,
    },
    featuredReference: insightCards[0]?.reference || null,
  };

  setCache(cacheKey, payload);
  return payload;
}

async function initDB() {
  console.log('[DB2] Ensuring Turso schema...');
  await ensureUserTable();
  await ensureJournalTables();
  await ensureJournalAiTable();
  await ensureIndexTables();
  await ensureTagMapTables();
  await rebuildTagMapsFromIndexes();
  await db.execute("UPDATE journal_entries SET ai_status = 'pending' WHERE ai_status = 'processing'");
  console.log('[DB2] Schema ready.');
}

function getRetryDelayMinutes(attempts) {
  if (attempts <= 1) return 5;
  if (attempts === 2) return 15;
  if (attempts === 3) return 60;
  if (attempts === 4) return 180;
  return 720;
}

let processSoonTimer = null;

function scheduleProcessSoon(delayMs = 1000) {
  if (processSoonTimer) return;
  processSoonTimer = setTimeout(async () => {
    processSoonTimer = null;
    await pollPendingJournals();
  }, delayMs);
}

const OPENROUTER_MODELS = [
  'stepfun/step-3.5-flash:free',
  'arcee-ai/trinity-large-preview:free',
  'google/gemma-3-27b-it:free',
  'google/gemma-3-12b-it:free',
  'meta-llama/llama-3.3-70b-instruct:free',
  'nousresearch/hermes-3-llama-3.1-405b:free',
  'mistralai/mistral-small-3.1-24b-instruct:free',
];

function parseAiJson(rawText) {
  let raw = rawText || '';
  if (raw.includes('```json')) raw = raw.split('```json')[1].split('```')[0].trim();
  else if (raw.includes('```')) raw = raw.split('```')[1].split('```')[0].trim();
  return JSON.parse(raw);
}

async function callLmStudio(prompt) {
  const res = await fetch(`${LM_STUDIO_BASE_URL}/api/v1/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: LM_STUDIO_MODEL,
      input: prompt,
      temperature: 0.2,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`LM Studio request failed (${res.status}): ${body.slice(0, 300)}`);
  }

  const data = await res.json();
  return parseAiJson(data.output?.[0]?.content || data.text || '');
}

async function callOpenRouter(prompt) {
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY is missing');
  }

  let lastError = null;
  for (const model of OPENROUTER_MODELS) {
    try {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [{ role: 'user', content: prompt }],
        }),
      });

      if (!res.ok) {
        lastError = new Error(`OpenRouter ${model} failed with ${res.status}`);
        continue;
      }

      const data = await res.json();
      return parseAiJson(data.choices?.[0]?.message?.content || '');
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError || new Error('All OpenRouter models failed');
}

async function callFanar(prompt) {
  if (!FANAR_API_KEY) {
    throw new Error('FANAR_API_KEY is missing');
  }

  const res = await fetch(`${FANAR_BASE_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${FANAR_API_KEY}`,
    },
    body: JSON.stringify({
      model: FANAR_MODEL,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.2,
      max_tokens: 800,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Fanar request failed (${res.status}): ${body.slice(0, 300)}`);
  }

  const data = await res.json();
  return parseAiJson(data.choices?.[0]?.message?.content || '');
}

async function callAI(prompt) {
  if (AI_PROVIDER === 'fanar') {
    return callFanar(prompt);
  }
  if (AI_PROVIDER === 'openrouter') {
    return callOpenRouter(prompt);
  }
  return callLmStudio(prompt);
}

async function generateFullInsight(journalText, previousJournalText) {
  const previousContext = previousJournalText
    ? `The user's PREVIOUS journal entry was: --- ${previousJournalText} --- Use this to suggest personalized tasks. `
    : "This is the user's first journal entry. ";

  const prompt =
    'You are an empathetic Islamic reflection assistant designed to help users connect their daily experiences with guidance from the Qur\'an. ' +
    previousContext +
    `The user's LATEST journal entry is: --- ${journalText} --- ` +
    'Your role is to reflect, relate, gently guide, and cite authentic Qur\'anic references. ' +
    'Do not give rulings, do not sound preachy, and do not invent verses. ' +
    'Identify the core topic or emotional theme in the journal. ' +
    'The "greeting" field must be one warm sentence in this style: "You wrote about <topic> yesterday. Here\'s what the Qur\'an says about that." ' +
    'Use a natural topic phrase such as patience, loneliness, gratitude, stress, family tension, or hope. ' +
    'The "insight" field must be 2-4 sentences that acknowledge the feeling gently, relate it to the selected Qur\'anic verse, and stay emotionally resonant and simple. ' +
    'Include ONE well-known authentic Qur\'anic reference only. ' +
    'The "quote" field should contain a short excerpt from that verse, and the "reference" field must include Surah name and ayah number. ' +
    'Generate 2-3 insight tags describing the emotion or theme (e.g. gratitude, patience). ' +
    'Suggest exactly 3 specific, actionable daily tasks the user can do today inspired by their journal. ' +
    'Generate 2-3 task tags describing the nature of the tasks (e.g. dhikr, charity, family). ' +
    'Output ONLY a raw minified JSON in this exact format (no markdown): ' +
    '{"greeting":"You wrote about...","insight":"...","quote":"...","reference":"...","tags":["tag1","tag2"],' +
    '"suggested_tasks":[{"title":"Task 1","description":"Do this specific thing"},{"title":"Task 2","description":"..."},{"title":"Task 3","description":"..."}],' +
    '"task_tags":["dhikr","charity"]}';

  return callAI(prompt);
}

async function upsertUser(uid, displayName, email, fcmToken) {
  await db.execute({
    sql: `
      INSERT INTO users (id, display_name, email, fcm_token)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = COALESCE(excluded.display_name, users.display_name),
        email = COALESCE(excluded.email, users.email),
        fcm_token = COALESCE(excluded.fcm_token, users.fcm_token),
        last_active = CURRENT_TIMESTAMP
    `,
    args: [uid, displayName || null, email || null, fcmToken || null],
  });
  clearUserCache(uid);
}

async function upsertJournal(uid, journal) {
  const initialAiScheduleSql = getInitialAiScheduleSql();
  const existingReflectionTags = await db.execute({
    sql: 'SELECT tag FROM tag_index WHERE user_id = ? AND journal_id = ?',
    args: [uid, journal.id],
  });
  const existingTaskTags = await db.execute({
    sql: 'SELECT tag FROM task_tag_index WHERE user_id = ? AND journal_id = ?',
    args: [uid, journal.id],
  });

  await db.execute({
    sql: `
      INSERT INTO journal_entries (id, user_id, content, ai_status, ai_attempts, ai_last_error, ai_next_retry_at, created_at)
      VALUES (?, ?, ?, 'pending', 0, NULL, ${initialAiScheduleSql}, CURRENT_TIMESTAMP)
      ON CONFLICT(id) DO UPDATE SET
        user_id = excluded.user_id,
        content = excluded.content,
        ai_status = 'pending',
        ai_attempts = 0,
        ai_last_error = NULL,
        ai_next_retry_at = ${initialAiScheduleSql},
        created_at = CURRENT_TIMESTAMP
    `,
    args: [journal.id, uid, journal.text],
  });

  await db.execute({ sql: 'DELETE FROM journal_ai WHERE journal_id = ?', args: [journal.id] });
  await db.execute({ sql: 'DELETE FROM tag_index WHERE journal_id = ?', args: [journal.id] });
  await db.execute({ sql: 'DELETE FROM task_tag_index WHERE journal_id = ?', args: [journal.id] });
  for (const row of existingReflectionTags.rows) {
    await removeJournalFromTagMap('user_tag_maps', uid, row.tag, journal.id);
  }
  for (const row of existingTaskTags.rows) {
    await removeJournalFromTagMap('user_task_tag_maps', uid, row.tag, journal.id);
  }
  clearJournalCache(journal.id);
}

let isProcessing = false;

async function pollPendingJournals() {
  if (isProcessing) return;
  isProcessing = true;

  try {
    const pending = await db.execute(
      `
        SELECT id, user_id, content, ai_attempts, created_at
        FROM journal_entries
        WHERE
          (
            ai_status = 'pending'
            AND COALESCE(ai_next_retry_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
          )
          OR (
            ai_status = 'failed'
            AND COALESCE(ai_next_retry_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
            AND COALESCE(ai_attempts, 0) < 5
          )
        ORDER BY
          CASE WHEN ai_status = 'pending' THEN 0 ELSE 1 END,
          created_at ASC
        LIMIT 3
      `
    );

    for (const journal of pending.rows) {
      await db.execute({
        sql: `
          UPDATE journal_entries
          SET
            ai_status = 'processing',
            ai_attempts = COALESCE(ai_attempts, 0) + 1,
            ai_last_error = NULL,
            ai_next_retry_at = NULL
          WHERE id = ?
        `,
        args: [journal.id],
      });

      try {
        const prevResult = await db.execute({
          sql: `
            SELECT j.content
            FROM journal_entries j
            JOIN journal_ai a ON j.id = a.journal_id
            WHERE j.user_id = ? AND j.id != ?
            ORDER BY j.created_at DESC
            LIMIT 1
          `,
          args: [journal.user_id, journal.id],
        });

        const previousJournalText = prevResult.rows[0]?.content || null;
        const ai = await generateFullInsight(journal.content, previousJournalText);
        const tags = (ai.tags || []).map(normalizeTag).filter(Boolean);
        const taskTags = (ai.task_tags || []).map(normalizeTag).filter(Boolean);

        const statements = [
          {
            sql: `
              INSERT INTO journal_ai (
                id, journal_id, user_id, summary, tags, quote, reference, suggested_tasks, task_tags, updated_at
              )
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
              ON CONFLICT(journal_id) DO UPDATE SET
                user_id = excluded.user_id,
                summary = excluded.summary,
                tags = excluded.tags,
                quote = excluded.quote,
                reference = excluded.reference,
                suggested_tasks = excluded.suggested_tasks,
                task_tags = excluded.task_tags,
                updated_at = CURRENT_TIMESTAMP
            `,
            args: [
              `ai_${journal.id}`,
              journal.id,
              journal.user_id,
              ai.insight || ai.greeting || 'Reflect on your day.',
              JSON.stringify(tags),
              ai.quote || '',
              ai.reference || '',
              JSON.stringify(ai.suggested_tasks || []),
              JSON.stringify(taskTags),
            ],
          },
          {
            sql: "UPDATE journal_entries SET ai_status = 'completed' WHERE id = ?",
            args: [journal.id],
          },
        ];

        for (const tag of tags) {
          statements.push({
            sql: 'INSERT OR IGNORE INTO tag_index (user_id, tag, journal_id) VALUES (?, ?, ?)',
            args: [journal.user_id, tag, journal.id],
          });
        }

        for (const tag of taskTags) {
          statements.push({
            sql: 'INSERT OR IGNORE INTO task_tag_index (user_id, tag, journal_id) VALUES (?, ?, ?)',
            args: [journal.user_id, tag, journal.id],
          });
        }

        await db.batch(statements, 'write');
        for (const tag of tags) {
          await upsertTagMapRow('user_tag_maps', journal.user_id, tag, journal.id, journal.created_at);
        }
        for (const tag of taskTags) {
          await upsertTagMapRow('user_task_tag_maps', journal.user_id, tag, journal.id, journal.created_at);
        }
        await recalculateUserMetadata(journal.user_id);
        clearUserCache(journal.user_id);
        clearJournalCache(journal.id);
      } catch (error) {
        console.error(`[POLLER ERROR] ${journal.id}: ${error.message}`);
        const attemptNumber = Number(journal.ai_attempts || 0) + 1;
        const retryDelayMinutes = getRetryDelayMinutes(attemptNumber);
        await db.execute({
          sql: `
            UPDATE journal_entries
            SET
              ai_status = 'failed',
              ai_last_error = ?,
              ai_next_retry_at = DATETIME('now', ?)
            WHERE id = ?
          `,
          args: [error.message.slice(0, 500), `+${retryDelayMinutes} minutes`, journal.id],
        });
        clearJournalCache(journal.id);
      }
    }
  } catch (error) {
    console.error('[POLLER DB ERROR]', error.message);
  } finally {
    isProcessing = false;
  }
}

setInterval(pollPendingJournals, AI_POLL_INTERVAL_MS);

const apiLimiter = rateLimit({ windowMs: 60 * 1000, max: 20 });

app.post('/api/v2/user/upsert', async (req, res) => {
  const { uid, displayName, email, fcmToken } = req.body;
  if (!uid) return res.status(400).json({ error: 'Missing uid' });

  try {
    await upsertUser(uid, displayName, email, fcmToken);
    await recalculateUserMetadata(uid);
    res.json({ success: true, uid });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/user/:uid', async (req, res) => {
  const { uid } = req.params;
  const cached = getCache(`user:${uid}`);
  if (cached) return res.json(cached);

  try {
    const userResult = await db.execute({ sql: 'SELECT * FROM users WHERE id = ?', args: [uid] });
    if (!userResult.rows.length) return res.status(404).json({ error: 'User not found' });

    const journalStats = await db.execute({
      sql: `
        SELECT
          COUNT(*) AS total_journals,
          SUM(CASE WHEN ai_status = 'completed' THEN 1 ELSE 0 END) AS completed_journals,
          MAX(created_at) AS latest_journal_at
        FROM journal_entries
        WHERE user_id = ?
      `,
      args: [uid],
    });

    const row = userResult.rows[0];
    const user = {
      ...row,
      relevant_tags: JSON.parse(row.relevant_tags || '[]'),
      stats: journalStats.rows[0],
    };

    setCache(`user:${uid}`, user);
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/user/:uid/journals', async (req, res) => {
  const { uid } = req.params;
  const { limit, status } = req.query;
  try {
    const queryArgs = [uid];
    let sql = `
      SELECT
        j.id,
        j.content,
        j.created_at,
        j.ai_status,
        a.summary,
        a.tags,
        a.quote,
        a.reference,
        a.suggested_tasks,
        a.task_tags
      FROM journal_entries j
      LEFT JOIN journal_ai a ON j.id = a.journal_id
      WHERE j.user_id = ?
    `;

    if (status) {
      sql += ' AND j.ai_status = ?';
      queryArgs.push(String(status));
    }

    sql += ' ORDER BY j.created_at DESC';

    const parsedLimit = Number(limit);
    if (Number.isFinite(parsedLimit) && parsedLimit > 0) {
      sql += ' LIMIT ?';
      queryArgs.push(Math.min(parsedLimit, 50));
    }

    const result = await db.execute({
      sql,
      args: queryArgs,
    });

    res.json(
      result.rows.map((row) => ({
        id: row.id,
        content: row.content,
        createdAt: row.created_at,
        status: row.ai_status,
        summary: row.summary || null,
        quote: row.quote || null,
        reference: row.reference || null,
        tags: JSON.parse(row.tags || '[]'),
        suggestedTasks: JSON.parse(row.suggested_tasks || '[]'),
        taskTags: JSON.parse(row.task_tags || '[]'),
      }))
    );
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Single round-trip sync: upsert user + all pending journals in one request.
app.post('/api/v2/journals/sync', apiLimiter, async (req, res) => {
  const { uid, displayName, email, fcmToken, journals } = req.body;
  if (!uid || !Array.isArray(journals)) {
    return res.status(400).json({ error: 'Missing uid or journals' });
  }

  try {
    await upsertUser(uid, displayName, email, fcmToken);

    let syncedCount = 0;
    for (const journal of journals) {
      if (!journal?.id || !journal?.text || !String(journal.text).trim()) continue;
      await upsertJournal(uid, { id: journal.id, text: String(journal.text).trim() });
      syncedCount += 1;
    }

    await recalculateUserMetadata(uid);
    clearUserCache(uid);
    if (syncedCount > 0) {
      scheduleProcessSoon();
    }

    res.status(202).json({
      success: true,
      uid,
      syncedCount,
      status: syncedCount > 0 ? 'pending' : 'noop',
    });
  } catch (error) {
    console.error('[SYNC ERROR]', error.message);
    res.status(500).json({ error: 'Database sync failed' });
  }
});

app.post('/api/v2/journal', apiLimiter, async (req, res) => {
  const { id, uid, text } = req.body;
  if (!id || !uid || !text) return res.status(400).json({ error: 'Missing id, uid, or text' });

  try {
    await upsertUser(uid);
    await upsertJournal(uid, { id, text: String(text).trim() });
    await recalculateUserMetadata(uid);
    clearUserCache(uid);
    scheduleProcessSoon();
    res.status(202).json({ success: true, id, status: 'pending' });
  } catch (error) {
    console.error('[API] DB Save Error:', error.message);
    res.status(500).json({ error: 'Database write failed' });
  }
});

app.get('/api/v2/journal/:id', async (req, res) => {
  const { id } = req.params;
  const cached = getCache(`journal:${id}`);
  if (cached) return res.json(cached);

  try {
    const result = await db.execute({
      sql: `
        SELECT
          j.id,
          j.user_id,
          j.content,
          j.created_at,
          j.ai_status,
          j.ai_attempts,
          j.ai_last_error,
          j.ai_next_retry_at,
          a.summary,
          a.tags,
          a.quote,
          a.reference,
          a.suggested_tasks,
          a.task_tags
        FROM journal_entries j
        LEFT JOIN journal_ai a ON j.id = a.journal_id
        WHERE j.id = ?
      `,
      args: [id],
    });

    if (!result.rows.length) return res.status(404).json({ error: 'Journal not found' });

    const row = result.rows[0];
    const payload = {
      id: row.id,
      userId: row.user_id,
      text: row.content,
      createdAt: row.created_at,
      status: row.ai_status,
      aiAttempts: row.ai_attempts,
      aiLastError: row.ai_last_error,
      aiNextRetryAt: row.ai_next_retry_at,
      insight: row.summary
        ? {
            summary: row.summary,
            tags: JSON.parse(row.tags || '[]'),
            quote: row.quote,
            reference: row.reference,
            suggestedTasks: JSON.parse(row.suggested_tasks || '[]'),
            taskTags: JSON.parse(row.task_tags || '[]'),
          }
        : null,
    };

    setCache(`journal:${id}`, payload);
    res.json(payload);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/tags', async (_req, res) => {
  try {
    res.json((await db.execute('SELECT * FROM tag_index')).rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/task-tags', async (_req, res) => {
  try {
    res.json((await db.execute('SELECT * FROM task_tag_index')).rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/user/:uid/tag-maps', async (req, res) => {
  const { uid } = req.params;
  try {
    const [reflectionMaps, taskMaps] = await Promise.all([
      db.execute({
        sql: 'SELECT tag, journal_ids, journal_refs, updated_at FROM user_tag_maps WHERE user_id = ? ORDER BY tag ASC',
        args: [uid],
      }),
      db.execute({
        sql: 'SELECT tag, journal_ids, journal_refs, updated_at FROM user_task_tag_maps WHERE user_id = ? ORDER BY tag ASC',
        args: [uid],
      }),
    ]);

    res.json({
      reflections: reflectionMaps.rows.map((row) => ({
        tag: row.tag,
        journalIds: JSON.parse(row.journal_ids || '[]'),
        journalRefs: JSON.parse(row.journal_refs || '[]'),
        updatedAt: row.updated_at,
      })),
      tasks: taskMaps.rows.map((row) => ({
        tag: row.tag,
        journalIds: JSON.parse(row.journal_ids || '[]'),
        journalRefs: JSON.parse(row.journal_refs || '[]'),
        updatedAt: row.updated_at,
      })),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/user/:uid/daily-content', async (req, res) => {
  const { uid } = req.params;
  const dayKey = String(req.query.day || new Date().toISOString().slice(0, 10));
  try {
    const payload = await buildDailyContent(uid, dayKey);
    res.json(payload);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/journal/:id/similar', async (req, res) => {
  const { id } = req.params;
  try {
    const journalResult = await db.execute({
      sql: 'SELECT id, user_id, created_at FROM journal_entries WHERE id = ?',
      args: [id],
    });
    if (!journalResult.rows.length) {
      return res.status(404).json({ error: 'Journal not found' });
    }

    const journal = journalResult.rows[0];
    const related = await loadSimilarMatchesForJournal(journal.user_id, id);

    res.json({
      journalId: journal.id,
      createdAt: journal.created_at,
      reflectionTags: related.reflectionTags,
      taskTags: related.taskTags,
      similarReflections: related.similarReflections,
      similarTasks: related.similarTasks,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/v2/journals/retry-failed', apiLimiter, async (req, res) => {
  const { uid } = req.body;
  if (!uid) return res.status(400).json({ error: 'Missing uid' });

  try {
    const failedRows = await db.execute({
      sql: `
        SELECT id
        FROM journal_entries
        WHERE user_id = ? AND ai_status = 'failed' AND COALESCE(ai_attempts, 0) < 5
      `,
      args: [uid],
    });
    const result = await db.execute({
      sql: `
        UPDATE journal_entries
        SET
          ai_status = 'pending',
          ai_next_retry_at = NULL
        WHERE user_id = ? AND ai_status = 'failed' AND COALESCE(ai_attempts, 0) < 5
      `,
      args: [uid],
    });
    for (const row of failedRows.rows) {
      clearJournalCache(row.id);
    }
    clearUserCache(uid);
    scheduleProcessSoon();
    res.json({ success: true, queued: Number(result.rowsAffected || 0) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/v2/ayah', async (req, res) => {
  const { ref } = req.query;
  if (!ref) return res.status(400).json({ error: 'Missing ref' });

  try {
    let ayahKey = ref;
    let url = '';

    if (ref === 'random') {
      url = 'https://api.alquran.cloud/v1/ayah/random/editions/quran-uthmani,en.transliteration,en.sahih';
    } else {
      const match = String(ref).match(/(\d+)[\s:]+(\d+)/);
      if (match) ayahKey = `${match[1]}:${match[2]}`;
      url = `https://api.alquran.cloud/v1/ayah/${ayahKey}/editions/quran-uthmani,en.transliteration,en.sahih`;
    }

    const textRes = await fetch(url);
    if (!textRes.ok) throw new Error('Failed to fetch from AlQuran Cloud');
    const textJson = await textRes.json();
    const ayahData = textJson.data;
    const arabicAyah = ayahData[0];
    const transliterationAyah = ayahData[1];
    const englishAyah = ayahData[2];
    const actualAyahNumber = arabicAyah.number;

    const audioRes = await fetch(`https://api.alquran.cloud/v1/ayah/${actualAyahNumber}/ar.alafasy`);
    const audioJson = await audioRes.json();

    res.json({
      arabic: arabicAyah.text,
      transliteration: transliterationAyah.text,
      english: englishAyah.text,
      surah: arabicAyah.surah.englishName,
      ayahNumber: arabicAyah.numberInSurah,
      audioUrl: audioJson.data.audio,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT_V2 || 3007;
initDB()
  .then(() => {
    app.listen(PORT, () => console.log(`[DB2] Turso Backend running on port ${PORT}`));
  })
  .catch((error) => {
    console.error('[DB2 BOOT ERROR]', error);
    process.exit(1);
  });
