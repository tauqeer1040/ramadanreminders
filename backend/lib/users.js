const db = require('./db');
const { encrypt } = require('../encryption');
const { clearUserCache } = require('./cache');

async function upsertUser(uid, displayName, email) {
  const encryptedEmail = email ? encrypt(email, uid) : null;
  await db.execute({
    sql: `
      INSERT INTO users (id, display_name, email)
      VALUES (?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = COALESCE(excluded.display_name, users.display_name),
        email = COALESCE(excluded.email, users.email),
        last_active = CURRENT_TIMESTAMP
    `,
    args: [uid, displayName || null, encryptedEmail],
  });
  clearUserCache(uid);
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

module.exports = { upsertUser, recalculateUserMetadata };
