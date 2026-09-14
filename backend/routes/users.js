const crypto = require('crypto');
const db = require('../lib/db');
const { getCache, setCache, clearUserCache } = require('../lib/cache');
const { decrypt } = require('../encryption');
const { upsertUser, recalculateUserMetadata, mergeUserStreak } = require('../lib/users');
const { upsertUserSchema, userStateSchema } = require('../lib/validation');

module.exports = function (app) {
  app.post('/api/v2/user/upsert', async (req, res) => {
    const parsed = upsertUserSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { displayName, email, catName } = parsed.data;
    const uid = req.uid;

    try {
      await upsertUser(uid, displayName, email, catName);
      await recalculateUserMetadata(uid);
      res.json({ success: true, uid });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Merge-only device backup (sign-in): stars/shields resolve to
  // max(server, device), purchases union. An older server row can never
  // shrink device-local progress.
  app.post('/api/v2/user/state', async (req, res) => {
    const parsed = userStateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const uid = req.uid;
    try {
      await upsertUser(uid, null, null, null);
      const cur = await db.execute({
        sql: 'SELECT stars, purchases, shield_balance FROM users WHERE id = ?',
        args: [uid],
      });
      const row = cur.rows[0] || {};
      const { stars, purchases, shieldBalance, streak, streakDate } = parsed.data;
      if (stars !== undefined) {
        const merged = Math.max(Number(row.stars ?? 0), stars);
        await db.execute({ sql: 'UPDATE users SET stars = ? WHERE id = ?', args: [merged, uid] });
      }
      // Date-aware merge (see mergeUserStreak): a lagging device report can
      // never roll the stored run backwards, and a broken streak stays broken.
      let streakOut = null;
      if (streak !== undefined) {
        const mergedStreak = await mergeUserStreak(uid, streak, streakDate ?? null);
        streakOut = mergedStreak;
      }
      if (shieldBalance !== undefined) {
        const merged = Math.max(Number(row.shield_balance ?? 0), shieldBalance);
        await db.execute({ sql: 'UPDATE users SET shield_balance = ? WHERE id = ?', args: [merged, uid] });
      }
      if (purchases !== undefined) {
        let existing = [];
        try {
          existing = JSON.parse(row.purchases ?? '[]');
          if (!Array.isArray(existing)) existing = [];
        } catch (_) {
          existing = [];
        }
        const merged = [...new Set([...existing, ...purchases])];
        await db.execute({ sql: 'UPDATE users SET purchases = ? WHERE id = ?', args: [JSON.stringify(merged), uid] });
      }
      clearUserCache(uid);
      const out = await db.execute({
        sql: 'SELECT stars, purchases, shield_balance FROM users WHERE id = ?',
        args: [uid],
      });
      res.json({
        success: true,
        ...(out.rows[0] || {}),
        // Echo the post-merge streak so the device can re-adopt truth when
        // its local clock/date was behind the server's.
        ...(streakOut ? { streak: streakOut.streak, streakDate: streakOut.streak_date } : {}),
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/user/:uid', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const uid = req.uid;
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
        email: row.email ? decrypt(row.email, uid) : null,
        relevant_tags: JSON.parse(row.relevant_tags || '[]'),
        stats: journalStats.rows[0],
      };

      setCache(`user:${uid}`, user);
      res.json(user);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Lightweight streak pull (users.streak is the primary store). Used by
  // the app at launch so DB-side streak changes show up locally.
  app.get('/api/v2/user/:uid/streak', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const uid = req.uid;
    try {
      const out = await db.execute({
        sql: 'SELECT streak, streak_date FROM users WHERE id = ?',
        args: [uid],
      });
      if (!out.rows.length) return res.status(404).json({ error: 'User not found' });
      const legacy = !(out.rows[0].streak > 0)
        ? await db.execute({
            sql: 'SELECT streak, updated_at FROM streaks WHERE uid = ?',
            args: [uid],
          })
        : null;
      const streak = Number(out.rows[0].streak ?? 0) > 0
        ? Number(out.rows[0].streak)
        : Number(legacy?.rows[0]?.streak ?? 0);
      const streakDate = Number(out.rows[0].streak ?? 0) > 0
        ? out.rows[0].streak_date
        : (legacy?.rows[0]?.updated_at || '').slice(0, 10) || null;
      res.json({ streak, streakDate, success: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/encryption-key', async (req, res) => {
    const key = crypto.createHmac('sha256', process.env.JOURNAL_ENCRYPTION_SECRET).update(req.uid).digest('base64');
    res.json({ key });
  });
};
