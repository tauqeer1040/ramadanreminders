// Google Play External Offers (EEA) — checkout session bridge.
// Flow: Android app checks PBL eligibility -> mints a session here (authed,
// carrying the fresh PBL externalTransactionToken) -> opens
// /pricing?price=pri_...&sid=... (NO PII in the URL, per program rules) ->
// pricing.astro resolves the sid server-side into Paddle customData ->
// Paddle webhook reports the charge to Google with the stored token.
//
// Sessions are opaque capability handles (256-bit), 30-min TTL, single
// checkout each. Raw sids never logged.
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const db = require('../lib/db');
const { externalOfferSessionSchema } = require('../lib/validation');
const googleExternal = require('../services/googleExternal');

const SESSION_TTL_MS = 30 * 60 * 1000;
const REPORT_RETRY_LIMIT = 20;

function mintSid() {
  return crypto.randomBytes(32).toString('hex');
}

module.exports = function (app) {
  const clientIp = (req) => req.headers['cf-connecting-ip'] || req.socket.remoteAddress;
  const limiter = rateLimit({
    windowMs: 60 * 1000,
    max: 10,
    keyGenerator: (req) => req.uid || clientIp(req),
    validate: { xForwardedForHeader: false },
  });
  const publicLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    keyGenerator: (req) => clientIp(req),
    validate: { xForwardedForHeader: false },
  });

  const enabled = (process.env.EXTERNAL_OFFERS_ENABLED || 'true').toLowerCase() !== 'false';
  const launchMode = process.env.EXTERNAL_OFFER_LAUNCH_MODE || 'external_browser';

  // Mint a checkout session. Body: { external_transaction_token, rc_customer_id? }
  app.post('/api/v2/external-offer/session', limiter, async (req, res) => {
    try {
      if (!enabled) return res.status(403).json({ error: 'External offers disabled' });
      const uid = req.uid;
      if (!uid) return res.status(401).json({ error: 'Auth required' });
      const parsed = externalOfferSessionSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
      }
      const now = Date.now();
      const sid = mintSid();
      await db.execute({
        sql: `INSERT INTO external_offer_sessions (sid, user_id, rc_customer_id, external_transaction_token, created_at, expires_at, consumed_at)
              VALUES (?, ?, ?, ?, ?, ?, NULL)`,
        args: [sid, uid, parsed.data.rc_customer_id || null, parsed.data.external_transaction_token, now, now + SESSION_TTL_MS],
      });
      res.json({ ok: true, sid, expires_in: SESSION_TTL_MS / 1000 });
    } catch (e) {
      console.error('[external-offer] session error:', e.message);
      res.status(500).json({ error: 'Failed to mint external-offer session' });
    }
  });

  // Server-driven config for the app (launch mode flag, kill-switch).
  app.get('/api/v2/external-offer/config', limiter, async (req, res) => {
    res.json({
      ok: true,
      enabled,
      program: 'external_offers',
      launch_mode: launchMode,
      package_name: googleExternal.packageName,
    });
  });

  // PUBLIC: resolve sid -> attribution for pricing.astro (no Firebase auth on
  // the marketing site). Returns only the app user id — never the PBL token,
  // email, or anything sensitive. Sid is a 256-bit unguessable capability.
  app.get('/api/v2/external-offer/resolve', publicLimiter, async (req, res) => {
    try {
      const sid = String(req.query.sid || '');
      if (!/^[A-Za-z0-9_-]{32,128}$/.test(sid)) return res.status(404).json({ error: 'Unknown session' });
      const r = await db.execute({
        sql: 'SELECT user_id, expires_at FROM external_offer_sessions WHERE sid = ?',
        args: [sid],
      });
      const row = r.rows[0];
      if (!row || Number(row.expires_at) <= Date.now()) {
        return res.status(404).json({ error: 'Unknown session' });
      }
      res.json({ ok: true, app_user_id: row.user_id });
    } catch (e) {
      console.error('[external-offer] resolve error:', e.message);
      res.status(500).json({ error: 'Resolve failed' });
    }
  });

  // Ops retry for failed Google reports. Guarded by INTERNAL_POLL_SECRET.
  app.post('/api/v2/external-offer/retry-reports', limiter, async (req, res) => {
    try {
      const secret = req.body?.secret || req.headers['x-internal-secret'];
      if (!secret || secret !== process.env.INTERNAL_POLL_SECRET) {
        return res.status(403).json({ error: 'Forbidden' });
      }
      const rows = await db.execute({
        sql: `SELECT * FROM google_external_reports WHERE status = 'failed' ORDER BY created_at ASC LIMIT ${REPORT_RETRY_LIMIT}`,
      });
      let ok = 0;
      const failed = [];
      for (const row of rows.rows) {
        if (row.kind === 'one_time' || row.kind === 'recurring_initial') {
          // Single-use PBL token was consumed on first attempt — replay needs
          // a fresh token via Play Console/MCP, not this endpoint.
          await db.execute({
            sql: `UPDATE google_external_reports SET google_error = 'needs_token_manual_replay' WHERE id = ?`,
            args: [row.id],
          });
          failed.push(row.external_transaction_id);
          continue;
        }
        try {
          if (String(row.kind).startsWith('refund')) {
            await googleExternal.refundExternalTransaction({ externalTransactionId: row.external_transaction_id });
          } else {
            await googleExternal.reportExternalTransaction({
              externalTransactionId: row.external_transaction_id,
              preTaxMicros: String(row.amount_micros || '0'),
              taxMicros: '0',
              currency: row.currency || 'USD',
              regionCode: row.country_code || 'US',
              transactionTime: new Date(Number(row.created_at)).toISOString(),
              kind: row.kind,
              token: undefined,
              initialId: undefined,
            });
          }
          await db.execute({
            sql: `UPDATE google_external_reports SET status = 'reported', reported_at = ?, google_error = NULL WHERE id = ?`,
            args: [Date.now(), row.id],
          });
          ok += 1;
        } catch (e) {
          // Retry path cannot resend tokens (consumed server-side on first
          // attempt) — mark needs_token so ops replays via Play Console/MCP.
          await db.execute({
            sql: `UPDATE google_external_reports SET google_error = ? WHERE id = ?`,
            args: [String(e.message).slice(0, 500), row.id],
          });
          failed.push(row.external_transaction_id);
        }
      }
      res.json({ ok: true, retried: rows.rows.length, reported: ok, still_failed: failed });
    } catch (e) {
      console.error('[external-offer] retry error:', e.message);
      res.status(500).json({ error: 'Retry failed' });
    }
  });
};
