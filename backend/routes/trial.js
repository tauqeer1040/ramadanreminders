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
        sql: 'SELECT subscription_status, subscription_trial_started_at, subscription_expires_at, grace_ms, trial_device_id FROM users WHERE id = ?',
        args: [uid],
      });

      if (!userResult.rows.length) {
        return res.json({ trialActive: true, daysRemaining: DEFAULT_TRIAL_DAYS, graceMs: DEFAULT_GRACE_MS, subscriptionStatus: 'none' });
      }

      const row = userResult.rows[0];
      const now = Date.now();
      let trialActive = false;
      let daysRemaining = 0;

      // Device claimed by an earlier uid's trial (reinstall + new login):
      // no fresh clock even though this uid never started one.
      if (!row.subscription_trial_started_at && row.trial_device_id) {
        const claimed = await db.execute({
          sql: `SELECT 1 FROM users
                WHERE trial_device_id = ? AND subscription_trial_started_at IS NOT NULL
                  AND id != ? LIMIT 1`,
          args: [row.trial_device_id, uid],
        });
        if (claimed.rows.length) {
          const result = { trialActive: false, daysRemaining: 0, graceMs: row.grace_ms ?? DEFAULT_GRACE_MS, subscriptionStatus: row.subscription_status || 'none', deviceClaimed: true };
          setCache(`trial:${uid}`, result);
          return res.json(result);
        }
      }

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

  // Server-authoritative trial clock: one trial per Firebase uid ever, and one
  // trial per device ever. Called once at onboarding finale (and defensively
  // at launch when no server start is known). Reinstalls get fresh local
  // prefs but the same device id — so a second uid claiming an already-used
  // device is denied instead of granted a fresh 3 days.
  app.post('/api/v2/trial/start', async (req, res) => {
    const uid = req.uid;
    const deviceId = String(req.body?.device_id || '').trim().slice(0, 128);
    if (!deviceId) {
      return res.status(400).json({ error: 'device_id required' });
    }
    try {
      const existing = await db.execute({
        sql: 'SELECT subscription_trial_started_at, trial_device_id FROM users WHERE id = ?',
        args: [uid],
      });
      const row = existing.rows[0];
      if (row?.subscription_trial_started_at) {
        deleteCache(`trial:${uid}`);
        return res.json({
          started: true,
          trialStart: row.subscription_trial_started_at,
          trialActive: Date.now() - row.subscription_trial_started_at < DEFAULT_TRIAL_DAYS * 24 * 60 * 60 * 1000,
        });
      }
      // Device already burned its trial on another uid (reinstall + new
      // login)? Deny — do not start a fresh clock. No cross-user data leaks:
      // only a boolean verdict is returned.
      const claimed = await db.execute({
        sql: `SELECT subscription_trial_started_at FROM users
              WHERE trial_device_id = ? AND subscription_trial_started_at IS NOT NULL
              ORDER BY subscription_trial_started_at ASC LIMIT 1`,
        args: [deviceId],
      });
      if (claimed.rows.length) {
        deleteCache(`trial:${uid}`);
        await db.execute({
          sql: `INSERT INTO users (id, trial_device_id) VALUES (?, ?)
                ON CONFLICT(id) DO UPDATE SET trial_device_id = excluded.trial_device_id`,
          args: [uid, deviceId],
        });
        return res.json({ started: false, reason: 'device_claimed', trialActive: false, daysRemaining: 0 });
      }
      const now = Date.now();
      await db.execute({
        sql: `INSERT INTO users (id, trial_device_id, subscription_trial_started_at)
              VALUES (?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                trial_device_id = excluded.trial_device_id,
                subscription_trial_started_at = COALESCE(users.subscription_trial_started_at, excluded.subscription_trial_started_at)`,
        args: [uid, deviceId, now],
      });
      deleteCache(`trial:${uid}`);
      return res.json({ started: true, trialStart: now, trialActive: true, daysRemaining: DEFAULT_TRIAL_DAYS });
    } catch (error) {
      console.error('[TRIAL] start error:', error.message);
      res.status(500).json({ error: 'Failed to start trial' });
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
