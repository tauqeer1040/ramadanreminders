const db = require('./db');

async function upsertStreak(uid, streak) {
  await db.execute({
    sql: `
      INSERT INTO streaks (uid, streak, updated_at)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(uid) DO UPDATE SET
        streak = excluded.streak,
        updated_at = CURRENT_TIMESTAMP
    `,
    args: [uid, streak],
  });
}

async function linkFriends(uidA, uidB) {
  if (!uidA || !uidB || uidA === uidB) return false;
  await db.batch(
    [
      {
        sql: 'INSERT OR IGNORE INTO friendships (user_a_uid, user_b_uid) VALUES (?, ?)',
        args: [uidA, uidB],
      },
      {
        sql: 'INSERT OR IGNORE INTO friendships (user_a_uid, user_b_uid) VALUES (?, ?)',
        args: [uidB, uidA],
      },
    ],
    'write'
  );
  return true;
}

async function getFriendStreak(uid) {
  const result = await db.execute({
    sql: `
      SELECT s.streak, s.updated_at FROM streaks s
      WHERE s.uid IN (
        SELECT user_b_uid FROM friendships WHERE user_a_uid = ?
        UNION
        SELECT user_a_uid FROM friendships WHERE user_b_uid = ?
      )
      ORDER BY s.updated_at DESC
      LIMIT 1
    `,
    args: [uid, uid],
  });
  if (!result.rows.length) return null;
  return { streak: Number(result.rows[0].streak), updatedAt: result.rows[0].updated_at };
}

async function getFriendInfo(uid) {
  const result = await db.execute({
    sql: `
      SELECT u.id, u.display_name, u.cat_name FROM users u
      WHERE u.id IN (
        SELECT user_b_uid FROM friendships WHERE user_a_uid = ?
        UNION
        SELECT user_a_uid FROM friendships WHERE user_b_uid = ?
      )
      LIMIT 1
    `,
    args: [uid, uid],
  });
  if (!result.rows.length) return null;
  const row = result.rows[0];
  return { uid: row.id, displayName: row.display_name || null, catName: row.cat_name || null };
}

module.exports = { upsertStreak, linkFriends, getFriendStreak, getFriendInfo };
