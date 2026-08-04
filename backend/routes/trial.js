const db = require('../lib/db');
const { getCache, setCache, deleteCache } = require('../lib/cache');

const DEFAULT_TRIAL_DAYS = 3;
const DEFAULT_GRACE_MS = 30 * 60 * 1000;

module.exports = function (app) {
  app.get('/api/v2/trial-status', async (req, res) => {
    const uid = req.uid;

    const cached = getCache(`trial:${uid}`);
    if (cached) return res.json(cached);

    try {
      const userResult = await db.execute({
        sql: 'SELECT subscription_status, subscription_trial_started_at, subscription_expires_at, grace_ms FROM users WHERE id = ?',
        args: [uid],
      });

      if (!userResult.rows.length) {
        return res.json({ trialActive: true, daysRemaining: DEFAULT_TRIAL_DAYS, graceMs: DEFAULT_GRACE_MS, subscriptionStatus: 'none' });
      }

      const row = userResult.rows[0];
      const now = Date.now();
      let trialActive = false;
      let daysRemaining = 0;

      const trialStart = row.subscription_trial_started_at;
      if (trialStart) {
        const elapsedDays = Math.floor((now - trialStart) / (24 * 60 * 60 * 1000));
        daysRemaining = Math.max(0, DEFAULT_TRIAL_DAYS - elapsedDays);
        trialActive = daysRemaining > 0;
      } else if (row.subscription_status === 'none' || !row.subscription_status) {
        trialActive = true;
        daysRemaining = DEFAULT_TRIAL_DAYS;
      }

      if (row.subscription_status === 'active' || row.subscription_status === 'trial') {
        const expiresAt = row.subscription_expires_at;
        if (expiresAt && now < expiresAt) {
          trialActive = true;
          daysRemaining = Math.max(1, Math.ceil((expiresAt - now) / (24 * 60 * 60 * 1000)));
        }
      }

      const result = {
        trialActive,
        daysRemaining,
        graceMs: row.grace_ms ?? DEFAULT_GRACE_MS,
        subscriptionStatus: row.subscription_status || 'none',
      };

      setCache(`trial:${uid}`, result);
      res.json(result);
    } catch (error) {
      console.error('[TRIAL] Error:', error.message);
      res.status(500).json({ error: 'Failed to check trial status' });
    }
  });

  app.post('/api/v2/trial/deduct-grace', async (req, res) => {
    const { uid } = req.body;
    if (!uid || req.uid !== uid) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
      await db.execute({
        sql: 'UPDATE users SET grace_ms = MAX(0, COALESCE(grace_ms, 1800000) - 60000) WHERE id = ?',
        args: [uid],
      });

      const read = await db.execute({
        sql: 'SELECT grace_ms FROM users WHERE id = ?',
        args: [uid],
      });

      const graceMs = read.rows[0]?.grace_ms ?? 0;

      deleteCache(`trial:${uid}`);

      res.json({ graceMs });
    } catch (error) {
      console.error('[TRIAL] Deduct error:', error.message);
      res.status(500).json({ error: 'Failed to deduct grace time' });
    }
  });
};
