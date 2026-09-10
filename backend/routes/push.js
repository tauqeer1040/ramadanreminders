const { verifyAuth } = require('../middleware/auth');
const db = require('../lib/db');
const { sendReminderPush } = require('../lib/fcm');

module.exports = function (app) {
  // Register/refresh the device's FCM token (called on app boot, token
  // rotation, and the reminders toggle). Upsert keyed by token.
  app.post('/api/v2/push/register', verifyAuth, async (req, res) => {
    try {
      const { token, platform, utcOffset, remindersEnabled } = req.body || {};
      if (!token || typeof token !== 'string' || token.length > 4096) {
        return res.status(400).json({ error: 'token required' });
      }
      const offset = Number.isFinite(Number(utcOffset))
        ? Math.max(-840, Math.min(840, Math.round(Number(utcOffset))))
        : 0;
      const enabled = remindersEnabled === false ? 0 : 1;

      await db.execute({
        sql: `
          INSERT INTO push_tokens (token, user_id, platform, utc_offset, reminders_enabled, updated_at)
          VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
          ON CONFLICT(token) DO UPDATE SET
            user_id = excluded.user_id,
            platform = excluded.platform,
            utc_offset = excluded.utc_offset,
            reminders_enabled = excluded.reminders_enabled,
            updated_at = CURRENT_TIMESTAMP
        `,
        args: [token, req.uid, String(platform || 'android').slice(0, 16), offset, enabled],
      });
      return res.json({ ok: true });
    } catch (error) {
      console.error('[push/register]', error);
      return res.status(500).json({ error: 'register failed' });
    }
  });

  // Turn the reminders toggle off/on without rotating the token.
  app.post('/api/v2/push/toggle', verifyAuth, async (req, res) => {
    try {
      const { enabled } = req.body || {};
      await db.execute({
        sql: 'UPDATE push_tokens SET reminders_enabled = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?',
        args: [enabled === false ? 0 : 1, req.uid],
      });
      return res.json({ ok: true });
    } catch (error) {
      console.error('[push/toggle]', error);
      return res.status(500).json({ error: 'toggle failed' });
    }
  });

  // Sign-out / token invalidation for this device.
  app.post('/api/v2/push/unregister', verifyAuth, async (req, res) => {
    try {
      const { token } = req.body || {};
      if (token) {
        await db.execute({
          sql: 'DELETE FROM push_tokens WHERE token = ? AND user_id = ?',
          args: [token, req.uid],
        });
      } else {
        await db.execute({
          sql: 'DELETE FROM push_tokens WHERE user_id = ?',
          args: [req.uid],
        });
      }
      return res.json({ ok: true });
    } catch (error) {
      console.error('[push/unregister]', error);
      return res.status(500).json({ error: 'unregister failed' });
    }
  });

  // Debug: fire one reminder push to the caller's own device(s).
  app.post('/api/v2/push/test', verifyAuth, async (req, res) => {
    try {
      const kind = req.body?.kind === 'night' ? 'night' : 'morning';
      const result = await db.execute({
        sql: 'SELECT token FROM push_tokens WHERE user_id = ?',
        args: [req.uid],
      });
      let sent = 0;
      const dead = [];
      for (const row of result.rows) {
        const r = await sendReminderPush(row.token, kind);
        if (r === true) sent++;
        else if (r && r.dead) dead.push(row.token);
      }
      if (dead.length) {
        await db.execute({
          sql: 'DELETE FROM push_tokens WHERE token IN ' + `(${dead.map(() => '?').join(',')})`,
          args: dead,
        });
      }
      return res.json({ ok: true, sent, removed: dead.length });
    } catch (error) {
      console.error('[push/test]', error);
      return res.status(500).json({ error: 'test failed' });
    }
  });
};
