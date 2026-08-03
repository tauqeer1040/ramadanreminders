const db = require('./db');
const { encrypt, decrypt } = require('../encryption');
const { clearJournalCache, clearUserCache } = require('./cache');
const { normalizeTag, removeJournalFromTagMap } = require('./tags');
const { getInitialAiScheduleSql } = require('./config');
const { sanitizeInsightCards } = require('./sanitize');

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

  const encryptedContent = encrypt(String(journal.text).trim(), uid);
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
    args: [journal.id, uid, encryptedContent],
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

function buildInsightCardsFromRows(rows, uid) {
  if (!rows.length) return [];

  const row = rows[0];
  if (!row.summary) return [];

  try {
    const decryptedSummary = uid ? decrypt(row.summary, uid) : row.summary;
    const parsed = JSON.parse(decryptedSummary);
    if (parsed.cards && Array.isArray(parsed.cards) && parsed.cards.length > 0) {
      const cards = sanitizeInsightCards(parsed.cards);
      return cards.map((card, i) => ({
        id: `card_${row.id}_${i}`,
        date: row.created_at,
        ...card,
      }));
    }
  } catch (_) {}

  return [];
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

module.exports = { upsertJournal, buildInsightCardsFromRows, loadSimilarMatchesForJournal };
