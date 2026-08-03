const crypto = require('crypto');
const db = require('../lib/db');
const { getCache, setCache } = require('../lib/cache');
const { decrypt } = require('../encryption');
const { upsertUser, recalculateUserMetadata } = require('../lib/users');
const { upsertUserSchema } = require('../lib/validation');

module.exports = function (app) {
  app.post('/api/v2/user/upsert', async (req, res) => {
    const parsed = upsertUserSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { displayName, email } = parsed.data;
    const uid = req.uid;

    try {
      await upsertUser(uid, displayName, email);
      await recalculateUserMetadata(uid);
      res.json({ success: true, uid });
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

  app.get('/api/v2/encryption-key', async (req, res) => {
    const key = crypto.createHmac('sha256', process.env.JOURNAL_ENCRYPTION_SECRET).update(req.uid).digest('base64');
    res.json({ key });
  });
};
