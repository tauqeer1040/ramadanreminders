const { pollPendingJournals } = require('../lib/ai-engine');
const { runAfterResponse } = require('../lib/request-context');
const { listErrors, logError } = require('../lib/error-log');

module.exports = function (app) {
  const checkSecret = (req) => {
    const secret = process.env.INTERNAL_POLL_SECRET;
    return secret && req.headers['x-internal-secret'] === secret;
  };

  app.post('/api/v2/internal/poll-ai', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    // Return immediately so the caller's `curl -m 60` never times out on a
    // long poll (which previously failed the job). The poll itself is kept
    // alive past the response via ctx.waitUntil() on Workers; elsewhere it
    // runs detached as before.
    const onError = (error) => {
      logError({ type: 'ai_poll_cron', message: error.message, stack: error.stack, route: 'internal/poll-ai' });
    };
    runAfterResponse(() => pollPendingJournals(), {
      fallback: () => pollPendingJournals().catch(onError),
      onError,
    });
    return res.status(202).json({ ok: true, triggered: true });
  });

  // Reminder push cron: POST /api/v2/internal/send-reminders?kind=morning|night
  // Sends FCM data messages to every registered device whose LOCAL wall-clock
  // hour matches the requested kind's hour. Per-user local time via the
  // utc_offset (minutes east of UTC) each device registered.
  // Cron guidance: run hourly (or every 15 min for drift tolerance).
  //   morning → 08:00 local, night → 22:00 local.
  app.post('/api/v2/internal/send-reminders', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const kind = req.query.kind === 'night' ? 'night' : 'morning';
    const targetHour = kind === 'night' ? 22 : 8;
    const onError = (error) => {
      logError({ type: 'reminder_push', message: error.message, stack: error.stack, route: 'internal/send-reminders' });
    };
    try {
      const db = require('../lib/db');
      const { sendReminderPush } = require('../lib/fcm');

      // Current UTC hour in "minutes east of UTC" space: offset qualifies when
      // its local hour equals targetHour. Local minutes vary within the hour,
      // so match on the hour bucket; hourly cron gives ≤1h drift, 15-min cron
      // tightens it. Devices are matched by: (targetHour*60 - utcOffsetMinutes)
      // mod 1440 ≈ current UTC minutes-of-day.
      const nowUtcMin = (() => {
        const d = new Date();
        return d.getUTCHours() * 60 + d.getUTCMinutes();
      })();
      // An offset qualifies if local-min-of-day (utc + offset) falls in
      // [target, target+60) — covers one hourly cron pass.
      const rows = await db.execute(
        'SELECT token, utc_offset FROM push_tokens WHERE reminders_enabled = 1'
      );
      let sent = 0;
      const dead = [];
      for (const row of rows.rows) {
        const localMin = ((nowUtcMin + Number(row.utc_offset)) % 1440 + 1440) % 1440;
        const localHour = Math.floor(localMin / 60);
        if (localHour !== targetHour) continue;
        // Send only on the first matching pass within the hour (nearest
        // quarter mark keeps repeat crons from double-sending).
        if (localMin % 60 >= 15 && req.query.dedupeWindow !== 'off') continue;
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
      return res.json({ ok: true, kind, sent, removed: dead.length, candidates: rows.rows.length });
    } catch (error) {
      onError(error);
      return res.status(500).json({ error: 'send-reminders failed' });
    }
  });

  // Deck pipeline diag: queue depth, stuck building rows, recent failures.
  // Lets a cron/uptime check catch a stalled queue without Firebase auth.
  app.get('/api/v2/internal/decks/health', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      const db = require('../lib/db');
      const [ready, served, building, stuck, failed, stale, done24, made24] = await Promise.all([
        db.execute(`SELECT COUNT(*) AS n FROM insight_decks WHERE status = 'ready'`),
        db.execute(`SELECT COUNT(*) AS n FROM insight_decks WHERE status = 'served'`),
        db.execute(`SELECT COUNT(*) AS n FROM insight_decks WHERE status = 'building'`),
        db.execute(`SELECT COUNT(*) AS n FROM insight_decks WHERE status = 'building' AND created_at < DATETIME('now', '-2 hours')`),
        db.execute(`SELECT COUNT(*) AS n FROM journal_entries WHERE ai_status = 'failed'`),
        db.execute(`SELECT COUNT(*) AS n,
                MAX(CAST((strftime('%s','now') - strftime('%s', COALESCE(ai_next_retry_at, created_at))) / 60 AS INTEGER)) AS oldest_min
              FROM journal_entries
              WHERE ai_status = 'pending'
                AND (ai_next_retry_at IS NULL OR ai_next_retry_at <= DATETIME('now', '-45 minutes'))`),
        db.execute(`SELECT COUNT(*) AS n FROM journal_ai WHERE updated_at > DATETIME('now', '-24 hours')`),
        db.execute(`SELECT COUNT(*) AS n FROM journal_entries WHERE created_at > DATETIME('now', '-24 hours')`),
      ]);
      res.json({
        ok: true,
        ready: Number(ready.rows[0]?.n || 0),
        served: Number(served.rows[0]?.n || 0),
        building: Number(building.rows[0]?.n || 0),
        stuckBuilding: Number(stuck.rows[0]?.n || 0),
        failedJournals: Number(failed.rows[0]?.n || 0),
        pendingStale: Number(stale.rows[0]?.n || 0),
        oldestPendingMin: stale.rows[0]?.oldest_min == null ? 0 : Number(stale.rows[0].oldest_min),
        completed24h: Number(done24.rows[0]?.n || 0),
        journals24h: Number(made24.rows[0]?.n || 0),
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/internal/errors', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      const rows = await listErrors(req.query.limit);
      res.json({ errors: rows });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Email pipeline diag: is Resend configured, and is anything being sent?
  // Never exposes the key itself — only whether one is set.
  app.get('/api/v2/internal/email-status', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      const db = require('../lib/db');
      const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
      const r = await db.execute({
        sql: `SELECT COUNT(*) AS n, MAX(created_at) AS last_at FROM continue_tokens WHERE created_at > ?`,
        args: [dayAgo],
      });
      res.json({
        resend_key_set: Boolean(process.env.RESEND_API_KEY),
        from: process.env.EMAIL_FROM || 'Meowmin <hello@meowmin.taucity.xyz>',
        sends_24h: Number(r.rows[0]?.n || 0),
        last_send_at: r.rows[0]?.last_at || null,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
