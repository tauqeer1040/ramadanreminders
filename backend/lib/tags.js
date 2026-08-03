const db = require('./db');

function normalizeTag(tag) {
  return String(tag || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function normalizeTaskContent(task) {
  return String(task?.title || task?.description || '').trim().toLowerCase();
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

module.exports = { normalizeTag, normalizeTaskContent, upsertTagMapRow, removeJournalFromTagMap };
