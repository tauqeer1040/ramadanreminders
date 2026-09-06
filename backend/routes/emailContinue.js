// Email-continuation signup (Netflix-style): token mint → delight email →
// status polling. All routes live under /api/v2 so verifyAuth applies and
// req.uid (Firebase UID, post-mandatory-OAuth) is authoritative.
// Tokens are opaque; only SHA-256 hashes touch the DB. Raw tokens never logged.
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const db = require('../lib/db');
const { decrypt } = require('../encryption');
const { upsertUser } = require('../lib/users');
const { emailContinueSchema } = require('../lib/validation');
const { enqueueEmailJob, attemptNow, autoSentToday, latestJobStatus } = require('../lib/email-queue');

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const RESEND_MAX_PER_DAY = 5;

function mintToken() {
  return crypto.randomBytes(32).toString('hex');
}
function hashToken(tok) {
  return crypto.createHash('sha256').update(String(tok)).digest('hex');
}
function maskEmail(email) {
  const [local, domain] = String(email).split('@');
  if (!domain) return '•••';
  return `${(local || '').slice(0, 1)}•••@${domain}`;
}

module.exports = function (app) {
  // Mirror app.js: avoid req.ip (express-rate-limit IPv6 validation).
  const clientIp = (req) => req.headers['cf-connecting-ip'] || req.socket.remoteAddress;
  const limiter = rateLimit({
    windowMs: 60 * 1000,
    max: 10,
    keyGenerator: (req) => req.uid || clientIp(req),
    validate: { xForwardedForHeader: false },
  });

  // Polling is cheap reads at 6/min from every open gate — it gets its
  // own lenient bucket so it can never starve mint/resend (the bug that
  // made Resend fail with 429 right after screen open).
  const pollLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 120,
    keyGenerator: (req) => req.uid || clientIp(req),
    validate: { xForwardedForHeader: false },
  });

  // Mint (or re-mint) a continue token + send the delight email.
  app.post('/api/v2/email-continue', limiter, async (req, res) => {
    try {
      const parsed = emailContinueSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
      }
      const uid = req.uid;
      if (!uid) return res.status(401).json({ error: 'Auth required' });
      const { email, displayName, snapshot, trigger } = parsed.data;
      const now = Date.now();

      await upsertUser(uid, displayName || null, email, null);

      // Auto-mint dedupe: one auto send per user per day. Explicit taps
      // (trigger manual) always send. The token still rotates so links
      // stay single-use; polling falls back to the stored token.
      const manual = trigger === 'manual';
      if (!manual && await autoSentToday(uid)) {
        const tokD = mintToken();
        await db.execute({
          sql: `INSERT INTO continue_tokens (tok_hash, user_id, created_at, expires_at, consumed_at, resend_count, last_sent_at, snapshot)
                VALUES (?, ?, ?, ?, NULL, 0, ?, ?)`,
          args: [hashToken(tokD), uid, now, now + TOKEN_TTL_MS, now, snapshot ? JSON.stringify(snapshot) : null],
        });
        return res.json({ ok: true, emailed: true, deduped: true, queued: false, email_id: null, expires_in: TOKEN_TTL_MS / 1000, email_masked: maskEmail(email), tok: tokD });
      }

      // Single active token per user: drop prior unconsumed rows.
      await db.execute({ sql: 'DELETE FROM continue_tokens WHERE user_id = ? AND consumed_at IS NULL', args: [uid] });

      const tok = mintToken();
      await db.execute({
        sql: `INSERT INTO continue_tokens (tok_hash, user_id, created_at, expires_at, consumed_at, resend_count, last_sent_at, snapshot)
              VALUES (?, ?, ?, ?, NULL, 0, ?, ?)`,
        args: [hashToken(tok), uid, now, now + TOKEN_TTL_MS, now, snapshot ? JSON.stringify(snapshot) : null],
      });

      // Queue + immediate attempt: healthy sends land in seconds, failures
      // stay queued for the worker instead of dying silently.
      const jobId = await enqueueEmailJob({
        user_id: uid, email, kind: manual ? 'manual' : 'auto',
        tok, tok_hash: hashToken(tok),
        snapshot, display_name: displayName || null,
      });
      const attempt = await attemptNow(jobId);
      const emailed = attempt != null && attempt.ok === true;
      res.json({ ok: true, emailed, queued: !emailed, email_id: (attempt && attempt.id) || null, expires_in: TOKEN_TTL_MS / 1000, email_masked: maskEmail(email), tok });
    } catch (e) {
      console.error('[email-continue] error:', e.message);
      res.status(500).json({ error: 'Failed to start email continuation' });
    }
  });

  // GET welcome sender. Deliberate GET-with-side-effect for one-line app
  // calls — hardened so it cannot be abused:
  // - Firebase Bearer required (prefetchers/crawlers/<img> can't forge it).
  // - Recipient resolved SERVER-side (token email claim, then users.email).
  //   Any ?email= parameter is ignored — it can only ever mail you.
  // - no-store + Vary: Authorization, same rate limits + daily caps.
  app.get('/api/v2/email-continue/send', limiter, async (req, res) => {
    try {
      res.set('Cache-Control', 'no-store');
      res.set('Vary', 'Authorization');
      const uid = req.uid;
      if (!uid) return res.status(401).json({ error: 'Auth required' });
      const manual = req.query.trigger === 'manual';
      const now = Date.now();

      let email = (typeof req.email === 'string' && req.email.includes('@')) ? req.email : null;
      if (!email) {
        // users.email is encrypted at rest — decrypt with the uid key.
        try {
          const u = await db.execute({ sql: 'SELECT email FROM users WHERE id = ?', args: [uid] });
          const raw = u.rows[0]?.email;
          if (typeof raw === 'string' && raw) {
            let dec = raw;
            try { dec = decrypt(raw, uid); } catch (_) {}
            if (typeof dec === 'string' && dec.includes('@')) email = dec;
          }
        } catch (_) {}
      }
      if (!email) return res.status(400).json({ error: 'No email on file — register one first' });

      if (!manual && await autoSentToday(uid)) {
        return res.json({ ok: true, emailed: true, deduped: true, queued: false, email_id: null, email_masked: maskEmail(email), tok: null });
      }

      await db.execute({ sql: 'DELETE FROM continue_tokens WHERE user_id = ? AND consumed_at IS NULL', args: [uid] });
      const tok = mintToken();
      await db.execute({
        sql: `INSERT INTO continue_tokens (tok_hash, user_id, created_at, expires_at, consumed_at, resend_count, last_sent_at, snapshot)
              VALUES (?, ?, ?, ?, NULL, 0, ?, NULL)`,
        args: [hashToken(tok), uid, now, now + TOKEN_TTL_MS, now],
      });
      const jobId = await enqueueEmailJob({
        user_id: uid, email, kind: manual ? 'manual' : 'auto',
        tok, tok_hash: hashToken(tok), snapshot: undefined, display_name: null,
      });
      const attempt = await attemptNow(jobId);
      const emailed = attempt != null && attempt.ok === true;
      res.json({ ok: true, emailed, queued: !emailed, email_id: (attempt && attempt.id) || null, email_masked: maskEmail(email), tok });
    } catch (e) {
      console.error('[email-continue/send] error:', e.message);
      res.status(500).json({ error: 'Failed to send welcome email' });
    }
  });

  // Resend (60s cooldown, 5/day). Reuses the live token; mints if expired.
  app.post('/api/v2/email-continue/resend', limiter, async (req, res) => {
    try {
      const uid = req.uid;
      if (!uid) return res.status(401).json({ error: 'Auth required' });
      const { email } = req.body || {};
      if (!email || !String(email).includes('@')) return res.status(400).json({ error: 'Valid email required' });
      const now = Date.now();

      const cur = await db.execute({
        sql: 'SELECT tok_hash, expires_at, resend_count, last_sent_at, snapshot FROM continue_tokens WHERE user_id = ? AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1',
        args: [uid],
      });
      let row = cur.rows[0] || null;
      const keepSnapshot = row?.snapshot || null;
      if (row && now - Number(row.last_sent_at || 0) < RESEND_COOLDOWN_MS) {
        return res.status(429).json({ error: 'Wait a minute before resending', retry_in: 60 });
      }
      const dayStart = now - TOKEN_TTL_MS;
      const cnt = await db.execute({
        sql: 'SELECT COALESCE(SUM(resend_count), 0) AS n FROM continue_tokens WHERE user_id = ? AND created_at > ?',
        args: [uid, dayStart],
      });
      if (Number(cnt.rows[0]?.n || 0) >= RESEND_MAX_PER_DAY) {
        return res.status(429).json({ error: 'Daily resend limit reached' });
      }

      let tok;
      if (row && Number(row.expires_at) > now) {
        // Reuse live token: we cannot recover the raw value, so rotate.
        await db.execute({ sql: 'DELETE FROM continue_tokens WHERE tok_hash = ?', args: [row.tok_hash] });
      }
      tok = mintToken();
      await db.execute({
        sql: `INSERT INTO continue_tokens (tok_hash, user_id, created_at, expires_at, consumed_at, resend_count, last_sent_at, snapshot)
              VALUES (?, ?, ?, ?, NULL, ?, ?, ?)`,
        args: [hashToken(tok), uid, now, now + TOKEN_TTL_MS, (row ? Number(row.resend_count || 0) : 0) + 1, now, keepSnapshot],
      });

      // Explicit user tap: always send (via queue with immediate attempt).
      const u = await db.execute({ sql: 'SELECT display_name FROM users WHERE id = ?', args: [uid] });
      const jobId = await enqueueEmailJob({
        user_id: uid, email, kind: 'resend',
        tok, tok_hash: hashToken(tok),
        snapshot: keepSnapshot ? JSON.parse(keepSnapshot) : undefined,
        display_name: u.rows[0]?.display_name || null,
      });
      const attempt = await attemptNow(jobId);
      const emailed = attempt != null && attempt.ok === true;
      res.json({ ok: true, emailed, queued: !emailed, email_id: (attempt && attempt.id) || null, expires_in: TOKEN_TTL_MS / 1000, tok });
    } catch (e) {
      console.error('[email-continue] resend error:', e.message);
      res.status(500).json({ error: 'Failed to resend' });
    }
  });

  // Poll target for the app: is this token valid, and did they purchase?
  app.get('/api/v2/continue-status', pollLimiter, async (req, res) => {
    try {
      const tok = String(req.query.tok || '');
      if (!tok) return res.status(400).json({ error: 'Missing tok' });
      const now = Date.now();
      const r = await db.execute({
        sql: 'SELECT user_id, expires_at, consumed_at FROM continue_tokens WHERE tok_hash = ?',
        args: [hashToken(tok)],
      });
      const row = r.rows[0];
      if (!row || Number(row.expires_at) <= now) return res.json({ valid: false, purchased: false });
      let purchased = row.consumed_at != null;
      if (!purchased) {
        const u = await db.execute({
          sql: "SELECT subscription_status FROM users WHERE id = ?",
          args: [row.user_id],
        });
        const st = u.rows[0]?.subscription_status;
        purchased = st === 'active' || st === 'trial';
      }
      const job = await latestJobStatus(row.user_id);
      res.json({
        valid: true,
        purchased,
        email_status: job ? job.status : null,
        email_sent_at: job && job.sent_at ? Number(job.sent_at) : null,
      });
    } catch (e) {
      console.error('[continue-status] error:', e.message);
      res.status(500).json({ error: 'Status check failed' });
    }
  });
};
