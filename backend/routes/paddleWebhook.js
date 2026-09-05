const crypto = require('crypto');
const db = require('../lib/db');

// Paddle webhook handler - hybrid DB entitlement write
// Verifies Paddle-Signature + IP allowlist, then updates users table

let cachedIpCidrs = null;
let ipCacheAt = 0;

async function getPaddleIps() {
  if (cachedIpCidrs && Date.now() - ipCacheAt < 1000 * 60 * 60 * 24) return cachedIpCidrs;
  try {
    const res = await fetch('https://api.paddle.com/ips');
    const json = await res.json();
    cachedIpCidrs = json.data?.ipv4_cidrs || [];
    ipCacheAt = Date.now();
    console.log(`[PADDLE WEBHOOK] Fetched ${cachedIpCidrs.length} IP CIDRs`);
    return cachedIpCidrs;
  } catch (e) {
    console.warn('[PADDLE WEBHOOK] Failed to fetch IPs:', e.message);
    return cachedIpCidrs || [];
  }
}

function ipMatchesCidr(ip, cidr) {
  // CIDR is /32, so exact match. Handle X-Forwarded / cf-connecting-ip may be single IP.
  const base = cidr.split('/')[0];
  return ip === base || ip?.endsWith(base);
}

function verifySignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader || !secret) return false;
  // Paddle-Signature: ts=1234567890;h1=abc123
  const parts = Object.fromEntries(signatureHeader.split(';').map(p => p.trim().split('=')));
  const ts = parts.ts;
  const h1 = parts.h1;
  if (!ts || !h1) return false;
  const payload = `${ts}:${rawBody}`;
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return expected === h1;
}

const SHIELD_AWARDS = {
  'monthly-challenge-1': 3,
  'monthly-challenge-5': 3,
  'four-month-journey': 18,
  'four-month-challenge': 18,
  'yearly': 72,
  'lifetime-gift': 150,
  'streak-shield': 1,
};

function shieldsForPrice(priceId, productId) {
  const hay = `${priceId || ''} ${productId || ''}`.toLowerCase();
  for (const [k, v] of Object.entries(SHIELD_AWARDS)) {
    if (hay.includes(k)) return v;
  }
  return 0;
}

// Maps one Paddle transaction.* event to a Google External Transactions
// report. Returns silently on skips; throws only on unexpected DB errors
// (caller catches). Google API failures are persisted as ledger 'failed'.
async function reportExternalOfferTransaction({ eventType, eventId, data, appUserId, eoSid }) {
  const g = require('../services/googleExternal');
  const now = Date.now();
  const paddleTxnId = data.id || null;
  const subId = data.subscription_id || null;
  const s = await db.execute({
    sql: 'SELECT user_id, external_transaction_token, expires_at FROM external_offer_sessions WHERE sid = ?',
    args: [String(eoSid)],
  });
  const sess = s.rows[0] || null;
  const uid = appUserId || sess?.user_id || null;
  const token = sess?.external_transaction_token || null;
  const currency = String(data.currency_code || 'USD').toUpperCase();
  const region = String(data.customer?.address?.country_code || data.address?.country_code || '').toUpperCase();
  const totals = data.totals || {};

  async function ledger(row) {
    const r = await db.execute({
      sql: `INSERT OR IGNORE INTO google_external_reports
            (external_transaction_id, paddle_event_id, paddle_transaction_id, paddle_subscription_id,
             user_id, kind, amount_micros, currency, country_code, fee_micros, status, google_error, reported_at, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        row.external_transaction_id, eventId, paddleTxnId, subId, uid, row.kind,
        row.amount_micros ?? null, currency, region || null, row.fee_micros ?? null,
        row.status, row.google_error ?? null, row.reported_at ?? null, now,
      ],
    });
    return r;
  }

  if (!paddleTxnId || !/^[A-Za-z0-9_-]{1,63}$/.test(paddleTxnId)) {
    await ledger({ external_transaction_id: `skipped:${eventId}`, kind: eventType === 'transaction.refunded' ? 'refund_skipped' : 'charge_skipped', status: 'skipped', google_error: 'missing paddle txn id' });
    return;
  }

  if (eventType === 'transaction.refunded') {
    const prior = await db.execute({
      sql: `SELECT id FROM google_external_reports WHERE external_transaction_id = ? AND status = 'reported'`,
      args: [paddleTxnId],
    });
    if (!prior.rows[0]) {
      await ledger({ external_transaction_id: paddleTxnId, kind: 'refund_skipped', status: 'skipped', google_error: 'no prior report for this txn' });
      return;
    }
    await ledger({ external_transaction_id: paddleTxnId, kind: 'refund', status: 'pending' });
    try {
      await g.refundExternalTransaction({ externalTransactionId: paddleTxnId });
      await db.execute({ sql: `UPDATE google_external_reports SET status = 'reported', reported_at = ? WHERE external_transaction_id = ?`, args: [now, paddleTxnId] });
      console.log(`[PADDLE WEBHOOK] Reported Google external refund ${paddleTxnId}`);
    } catch (e) {
      await db.execute({ sql: `UPDATE google_external_reports SET status = 'failed', google_error = ? WHERE external_transaction_id = ?`, args: [String(e.message).slice(0, 500), paddleTxnId] });
      console.error('[PADDLE WEBHOOK] Google refund report failed:', e.message);
    }
    return;
  }

  // transaction.completed
  if (!region || region.length !== 2) {
    await ledger({ external_transaction_id: paddleTxnId, kind: 'charge_skipped', status: 'skipped', google_error: 'missing customer country' });
    return;
  }
  let kind;
  let initialId = null;
  if (!subId) {
    kind = 'one_time';
    if (!token) {
      await ledger({ external_transaction_id: paddleTxnId, kind: 'charge_skipped', status: 'skipped', google_error: 'missing PBL token (session unknown/expired)' });
      return;
    }
  } else {
    const prior = await db.execute({
      sql: `SELECT external_transaction_id FROM google_external_reports
            WHERE paddle_subscription_id = ? AND status = 'reported' AND kind LIKE 'recurring%' ORDER BY created_at ASC LIMIT 1`,
      args: [subId],
    });
    if (prior.rows[0]) {
      kind = 'recurring_subsequent';
      initialId = prior.rows[0].external_transaction_id;
    } else {
      kind = 'recurring_initial';
      if (!token) {
        await ledger({ external_transaction_id: paddleTxnId, kind: 'charge_skipped', status: 'skipped', google_error: 'missing PBL token (session unknown/expired)' });
        return;
      }
    }
  }
  const preTax = g.centsToMicrosStr(totals.subtotal ?? totals.total ?? data.amount ?? 0);
  const tax = g.centsToMicrosStr(totals.tax ?? 0);
  const fee = g.estimateFeeMicros(kind, preTax);
  const txnTime = data.billed_at || new Date(now).toISOString();
  await ledger({ external_transaction_id: paddleTxnId, kind, amount_micros: Number(preTax), fee_micros: fee, status: 'pending' });
  try {
    await g.reportExternalTransaction({
      externalTransactionId: paddleTxnId,
      preTaxMicros: preTax,
      taxMicros: tax,
      currency,
      regionCode: region,
      transactionTime: txnTime,
      kind,
      token: token || undefined,
      initialId: initialId || undefined,
    });
    await db.execute({ sql: `UPDATE google_external_reports SET status = 'reported', reported_at = ? WHERE external_transaction_id = ?`, args: [now, paddleTxnId] });
    if (sess && (kind === 'one_time' || kind === 'recurring_initial')) {
      await db.execute({ sql: `UPDATE external_offer_sessions SET consumed_at = ? WHERE sid = ?`, args: [now, String(eoSid)] });
    }
    console.log(`[PADDLE WEBHOOK] Reported Google external ${kind} ${paddleTxnId} (~${currency} fee est ${(fee / 1e6).toFixed(2)})`);
  } catch (e) {
    await db.execute({ sql: `UPDATE google_external_reports SET status = 'failed', google_error = ? WHERE external_transaction_id = ?`, args: [String(e.message).slice(0, 500), paddleTxnId] });
    console.error('[PADDLE WEBHOOK] Google charge report failed:', e.message);
  }
}

module.exports = function (app) {
  app.post('/api/paddle-webhook', async (req, res) => {
    const rawBody = req.rawBody;
    const signature = req.headers['paddle-signature'];
    const secret = process.env.PADDLE_NOTIFICATION_WEBHOOK_SECRET;

    // IP allowlist - fetch source of truth, reject others
    const clientIp = req.headers['cf-connecting-ip'] || req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress;
    const cidrs = await getPaddleIps();
    if (cidrs.length > 0) {
      const allowed = cidrs.some(cidr => ipMatchesCidr(clientIp, cidr));
      if (!allowed) {
        console.warn(`[PADDLE WEBHOOK] Rejected IP ${clientIp} not in allowlist`);
        // Do not leak - still return 403
        return res.status(403).json({ error: 'Forbidden' });
      }
    }

    if (secret) {
      if (!verifySignature(rawBody, signature, secret)) {
        console.warn('[PADDLE WEBHOOK] Invalid signature');
        return res.status(401).json({ error: 'Invalid signature' });
      }
    } else {
      console.warn('[PADDLE WEBHOOK] PADDLE_NOTIFICATION_WEBHOOK_SECRET not set - skipping signature verify');
    }

    try {
      const event = req.body;
      const eventId = event?.event_id || event?.data?.id || event?.eventId;
      const eventType = event?.event_type || event?.type;

      if (!eventId) {
        return res.status(400).json({ error: 'Missing event_id' });
      }

      // Idempotency
      const existing = await db.execute({ sql: 'SELECT 1 FROM webhook_events WHERE event_id = ?', args: [eventId] });
      if (existing.rows.length > 0) {
        console.log(`[PADDLE WEBHOOK] Duplicate ${eventId} ${eventType}, skip`);
        return res.status(200).json({ received: true, deduped: true });
      }

      console.log(`[PADDLE WEBHOOK] ${eventType} ${eventId}`);
      const data = event?.data || {};
      // Try to resolve appUserId: custom_data.appUserId, custom_data.app_user_id, or customer email lookup
      let appUserId = data.custom_data?.appUserId || data.custom_data?.app_user_id || data.custom_data?.uid || null;
      const customerId = data.customer_id || data.customer?.id || null;
      const priceId = data.items?.[0]?.price?.id || data.items?.[0]?.price_id || data.price_id || null;
      const productId = data.items?.[0]?.price?.product_id || data.product_id || null;

      // Fallback: lookup user by Paddle customer email if no custom_data
      if (!appUserId && data.customer?.email) {
        const email = data.customer.email;
        const r = await db.execute({ sql: 'SELECT id FROM users WHERE email = ?', args: [email] });
        if (r.rows[0]) appUserId = r.rows[0].id;
      }

      // Email-continuation attribution: server-minted single-use token is
      // authoritative (avoids plaintext-email matching; emails are encrypted
      // at rest). Consumed on first active event so status polling flips.
      const continueToken = data.custom_data?.continue_token || data.custom_data?.continueToken || null;
      if (continueToken) {
        try {
          const tokHash = crypto.createHash('sha256').update(String(continueToken)).digest('hex');
          const t = await db.execute({
            sql: 'SELECT user_id, expires_at, consumed_at FROM continue_tokens WHERE tok_hash = ?',
            args: [tokHash],
          });
          const tRow = t.rows[0];
          if (tRow && Number(tRow.expires_at) > Date.now()) {
            if (!appUserId) {
              appUserId = tRow.user_id;
            } else if (appUserId !== tRow.user_id) {
              console.warn(`[PADDLE WEBHOOK] continue_token user ${tRow.user_id} != custom_data user ${appUserId}; trusting token`);
              appUserId = tRow.user_id;
            }
            const activeEvt = ['subscription.activated', 'subscription.trialing', 'subscription.resumed', 'transaction.completed', 'transaction.paid'].includes(eventType);
            if (activeEvt && appUserId && tRow.consumed_at == null) {
              await db.execute({ sql: 'UPDATE continue_tokens SET consumed_at = ? WHERE tok_hash = ?', args: [Date.now(), tokHash] });
              console.log(`[PADDLE WEBHOOK] Consumed continue_token for ${appUserId} (${eventType})`);
            }
          }
        } catch (e) {
          console.error('[PADDLE WEBHOOK] continue_token attribution failed:', e.message);
        }
      }

      const now = Date.now();

      // Map Paddle events to users table
      const isActiveEvent = ['subscription.activated', 'subscription.created', 'subscription.resumed', 'subscription.trialing', 'transaction.completed', 'transaction.paid'].includes(eventType);
      const isCancelEvent = ['subscription.canceled', 'subscription.paused', 'subscription.past_due'].includes(eventType);

      if (appUserId) {
        if (eventType === 'subscription.activated' || eventType === 'subscription.trialing' || eventType === 'subscription.resumed') {
          const expiresAt = data.current_billing_period?.ends_at ? new Date(data.current_billing_period.ends_at).getTime() : null;
          const isTrial = eventType === 'subscription.trialing';
          await db.execute({
            sql: `UPDATE users SET subscription_status = ?, subscription_product_id = ?, subscription_expires_at = ?, subscription_trial_started_at = COALESCE(subscription_trial_started_at, ?) WHERE id = ?`,
            args: [isTrial ? 'trial' : 'active', productId || priceId || 'paddle', expiresAt, isTrial ? now : null, appUserId],
          });
          const shields = shieldsForPrice(priceId, productId);
          if (shields > 0) {
            await db.execute({ sql: `UPDATE users SET shield_balance = COALESCE(shield_balance,0) + ? WHERE id = ?`, args: [shields, appUserId] });
            console.log(`[PADDLE WEBHOOK] Awarded ${shields} shields to ${appUserId}`);
          }
        } else if (eventType === 'subscription.updated' || eventType === 'subscription.activated') {
          const expiresAt = data.current_billing_period?.ends_at ? new Date(data.current_billing_period.ends_at).getTime() : null;
          await db.execute({ sql: `UPDATE users SET subscription_product_id = ?, subscription_expires_at = ? WHERE id = ?`, args: [productId || priceId, expiresAt, appUserId] });
        } else if (eventType === 'subscription.canceled') {
          await db.execute({ sql: `UPDATE users SET subscription_status = 'cancelled' WHERE id = ?`, args: [appUserId] });
        } else if (eventType === 'subscription.past_due' || eventType === 'subscription.paused') {
          await db.execute({ sql: `UPDATE users SET subscription_status = 'past_due' WHERE id = ?`, args: [appUserId] });
        } else if (eventType === 'transaction.completed' && !data.subscription_id) {
          // One-time / lifetime / streak shield
          const shields = shieldsForPrice(priceId, productId);
          if (shields > 0 && productId !== 'streak-shield') {
            // Lifetime etc already handled via subscription, but ensure active
            await db.execute({ sql: `UPDATE users SET subscription_status = 'active', subscription_product_id = ?, shield_balance = COALESCE(shield_balance,0) + ? WHERE id = ?`, args: [productId || priceId, shields, appUserId] });
          } else if (shields === 1) {
            // Streak shield consumable
            await db.execute({ sql: `UPDATE users SET shield_balance = COALESCE(shield_balance,0) + 1 WHERE id = ?`, args: [appUserId] });
          }
          console.log(`[PADDLE WEBHOOK] Transaction ${eventId} for ${appUserId} product ${productId} price ${priceId}`);
        }
        // Handle cancellations via transaction if needed
        if (isCancelEvent && !appUserId) {
          console.warn(`[PADDLE WEBHOOK] No appUserId for ${eventType}`);
        }
      } else {
        console.warn(`[PADDLE WEBHOOK] No appUserId resolved for ${eventType} ${eventId}, customer ${customerId}`);
      }

      // Google Play External Offers reporting: only for checkouts that followed
      // an in-app external-offer link-out (sid in custom_data). Web/email
      // purchases are NOT Play-attributable. Report transaction.* only (never
      // subscription.*): Paddle emits both subscription.activated and
      // transaction.completed for the first charge — the transaction is the
      // charge of record. Never throws: failures land in the ledger for retry.
      const eoSid = data.custom_data?.external_offer_sid || data.custom_data?.externalOfferSid || null;
      if (eoSid && (eventType === 'transaction.completed' || eventType === 'transaction.refunded')) {
        try {
          await reportExternalOfferTransaction({ eventType, eventId, data, appUserId, eoSid });
        } catch (e) {
          console.error('[PADDLE WEBHOOK] external-offer report failed:', e.message);
        }
      }

      await db.execute({ sql: 'INSERT OR IGNORE INTO webhook_events (event_id, type, uid, processed_at) VALUES (?, ?, ?, ?)', args: [eventId, eventType, appUserId || 'unknown', now] });

      res.status(200).json({ received: true });
    } catch (e) {
      console.error('[PADDLE WEBHOOK] Error:', e.message, e.stack);
      res.status(500).json({ error: 'Webhook failed' });
    }
  });

  // Helper to warm IP cache on boot
  getPaddleIps().catch(() => {});
};
