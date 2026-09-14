const db = require('./db');
const { encrypt } = require('../encryption');
const { clearUserCache } = require('./cache');

async function upsertUser(uid, displayName, email, catName) {
  const encryptedEmail = email ? encrypt(email, uid) : null;
  await db.execute({
    sql: `
      INSERT INTO users (id, display_name, email, cat_name)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = COALESCE(excluded.display_name, users.display_name),
        email = COALESCE(excluded.email, users.email),
        cat_name = COALESCE(excluded.cat_name, users.cat_name),
        last_active = CURRENT_TIMESTAMP
    `,
    args: [uid, displayName || null, encryptedEmail, catName || null],
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

// Days between two yyyy-MM-dd strings; null when either is unparseable.
function daysBetween(dateA, dateB) {
  const ta = Date.parse(`${dateA}T00:00:00Z`);
  const tb = Date.parse(`${dateB}T00:00:00Z`);
  if (Number.isNaN(ta) || Number.isNaN(tb)) return null;
  return Math.round((tb - ta) / 86400000);
}

/**
 * Date-aware streak merge into users.streak / users.streak_date. The
 * incoming (device) report wins only when it is not behind the stored
 * state:
 *  - stored date missing/unparseable      -> incoming adopted
 *  - incoming older than stored           -> ignored (lagging device)
 *  - same day                             -> max of the two
 *  - consecutive day                      -> max, date advances
 *  - gap > 1 day                          -> newer observation wins (the
 *    run broke somewhere offline; the freshest report describes reality)
 * Returns the stored { streak, streak_date } after the merge.
 */
async function mergeUserStreak(uid, streak, streakDate) {
  const cur = await db.execute({
    sql: 'SELECT streak, streak_date FROM users WHERE id = ?',
    args: [uid],
  });
  const row = cur.rows[0] || {};
  const curStreak = Number(row.streak ?? 0);
  const curDate = row.streak_date || null;

  let nextStreak = streak;
  let nextDate = streakDate || null;

  if (curDate && streakDate) {
    const delta = daysBetween(curDate, streakDate); // >0 -> incoming newer
    if (delta === null) {
      // Stored date unparseable: trust the incoming report.
    } else if (delta < 0) {
      nextStreak = curStreak;
      nextDate = curDate;
    } else if (delta === 0 || delta === 1) {
      nextStreak = Math.max(curStreak, streak);
      nextDate = delta === 0 ? curDate : streakDate;
    } else {
      // Gap: newest observation wins.
      nextStreak = streak;
      nextDate = streakDate;
    }
  }

  await db.execute({
    sql: 'UPDATE users SET streak = ?, streak_date = ? WHERE id = ?',
    args: [nextStreak, nextDate, uid],
  });
  clearUserCache(uid);
  return { streak: nextStreak, streak_date: nextDate };
}

module.exports = { upsertUser, recalculateUserMetadata, mergeUserStreak };
