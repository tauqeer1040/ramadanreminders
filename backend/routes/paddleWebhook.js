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
