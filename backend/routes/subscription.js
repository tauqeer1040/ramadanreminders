const crypto = require('crypto');
const db = require('../lib/db');
const { subscriptionSyncSchema, transferLifetimeSchema, transferClaimSchema } = require('../lib/validation');

const SHIELD_AWARDS = {
  'monthly-challenge-1': 3,
  'monthly-challenge-5': 3,
  'four-month-journey': 18,
  'yearly': 72,
  'lifetime-gift': 150,
};

function shieldsForProduct(productId) {
  if (!productId) return 0;
  const key = Object.keys(SHIELD_AWARDS).find(k => productId.includes(k));
  return SHIELD_AWARDS[key] || 0;
}

module.exports = function (app) {
  app.post('/api/v2/subscription/sync', async (req, res) => {
    const parsed = subscriptionSyncSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { appUserId, productId, status, expiresAt, periodType } = parsed.data;

    if (process.env.REVENUECAT_API_SECRET) {
      try {
        const verifyUrl = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`;
        const rcRes = await fetch(verifyUrl, {
          headers: { Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}` },
        });
        if (!rcRes.ok) throw new Error(`RevenueCat verify failed (${rcRes.status})`);
        const rcResponse = await rcRes.json();

        const entitlement = rcResponse?.subscriber?.entitlements?.['premium'] ||
          rcResponse?.subscriber?.entitlements?.['Meowmin Max'] ||
          rcResponse?.subscriber?.entitlements?.['Meowmin Pro'];
        if (!entitlement) {
          console.warn(`[Subscription Sync] No premium entitlement found for ${appUserId}`);
          return res.status(200).json({ received: true, verified: false });
        }

        const serverIsActive = entitlement.expires_at
          ? Date.now() < new Date(entitlement.expires_at).getTime()
          : entitlement.unlimited;
        const reportedIsActive = status === 'active' || status === 'trial';

        if (serverIsActive !== reportedIsActive) {
          console.warn(`[Subscription Sync] Mismatch for ${appUserId}: server=${serverIsActive}, reported=${reportedIsActive}`);
        }
      } catch (e) {
        console.error('[Subscription Sync] Verification failed:', e.message);
        return res.status(200).json({ received: true, verified: false });
      }
    }

    const now = Date.now();
    try {
      await db.execute({
        sql: `UPDATE users SET
          subscription_status = ?,
          subscription_product_id = ?,
          subscription_expires_at = ?,
          subscription_trial_started_at = COALESCE(subscription_trial_started_at, CASE WHEN ? = 'trial' THEN ? ELSE NULL END)
        WHERE id = ?`,
        args: [status, productId, expiresAt || null, periodType, now, appUserId],
      });

      // Award shields on first active subscription
      if (status === 'active' || status === 'trial') {
        const shields = shieldsForProduct(productId);
        if (shields > 0) {
          await db.execute({
            sql: `UPDATE users SET shield_balance = COALESCE(shield_balance, 0) + ? WHERE id = ?`,
            args: [shields, appUserId],
          });
          console.log(`[Subscription Sync] Awarded ${shields} shields to ${appUserId} for ${productId}`);
        }
      }

      res.json({ received: true, verified: true });
    } catch (error) {
      console.error('[Subscription Sync] DB error:', error.message);
      res.status(500).json({ error: 'Sync failed' });
    }
  });

  app.post('/api/v2/subscription/transfer', async (req, res) => {
    const parsed = transferLifetimeSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { recipientEmail } = parsed.data;
    const uid = req.uid;

    try {
      const userResult = await db.execute({
        sql: 'SELECT subscription_status, subscription_product_id FROM users WHERE id = ?',
        args: [uid],
      });
      const user = userResult.rows[0];
      if (!user || user.subscription_status !== 'active' || !user.subscription_product_id?.includes('lifetime')) {
        return res.status(403).json({ error: 'Only lifetime subscribers can transfer access' });
      }

      let groupResult = await db.execute({
        sql: 'SELECT * FROM family_groups WHERE owner_uid = ?',
        args: [uid],
      });

      if (groupResult.rows.length === 0) {
        const groupId = `fg_${uid}_${Date.now()}`;
        await db.execute({
          sql: `INSERT INTO family_groups (id, owner_uid, max_members, members) VALUES (?, ?, 3, ?)`,
          args: [groupId, uid, JSON.stringify([uid, recipientEmail])],
        });
        groupResult = await db.execute({
          sql: 'SELECT * FROM family_groups WHERE id = ?',
          args: [groupId],
        });
      } else {
        const group = groupResult.rows[0];
        const members = JSON.parse(group.members || '[]');
        if (members.includes(recipientEmail)) {
          return res.status(409).json({ error: 'Recipient already in group' });
        }
        if (members.length >= group.max_members) {
          return res.status(400).json({ error: 'Group is full (max 3 members)' });
        }
        members.push(recipientEmail);
        await db.execute({
          sql: 'UPDATE family_groups SET members = ? WHERE id = ?',
          args: [JSON.stringify(members), group.id],
        });
      }

      res.json({
        success: true,
        message: `Invitation sent to ${recipientEmail}. They'll receive Meowmin Max access once they sign up.`,
      });
    } catch (error) {
      console.error('[Transfer] DB error:', error.message);
      res.status(500).json({ error: 'Transfer failed' });
    }
  });

  app.get('/api/v2/subscription/shields', async (req, res) => {
    const uid = req.uid;
    try {
      const result = await db.execute({
        sql: 'SELECT shield_balance FROM users WHERE id = ?',
        args: [uid],
      });
      const shields = result.rows[0]?.shield_balance ?? 0;
      res.json({ shields });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // ---- Entitlement transfer (guest -> signed-in account) ----
  // When a guest (often anonymous) buys Max and later signs in with an
  // account that already exists (fresh uid), the purchase would be
  // orphaned on the guest uid. The app prepares a single-use transfer
  // token while still authed as guest, then claims it after sign-in.
  // Claim: mirrors DB subscription fields, grants an RC promotional
  // entitlement on the new uid, and moves Paddle custom_data so renewals
  // attribute to the new uid going forward.
  const TRANSFER_TTL_MS = 10 * 60 * 1000;
  const RC_ENTITLEMENT_ID = 'Meowmin Max';

  function promoDurationForProduct(productId) {
    const p = String(productId || '').toLowerCase();
    if (p.includes('lifetime')) return 'lifetime';
    if (p.includes('yearly') || p.includes('annual')) return 'yearly';
    if (p.includes('six') || p.includes('6_month')) return '6_month';
    if (p.includes('four') || p.includes('4_month')) return '6_month';
    if (p.includes('three') || p.includes('3_month')) return '3_month';
    if (p.includes('two') || p.includes('2_month')) return '2_month';
    return 'monthly';
  }

  async function rcEntitlementFor(appUserId) {
    if (!process.env.REVENUECAT_API_SECRET) return null;
    const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`;
    const rcRes = await fetch(url, {
      headers: { Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}` },
    });
    if (!rcRes.ok) return null;
    const rc = await rcRes.json();
    return rc?.subscriber?.entitlements?.[RC_ENTITLEMENT_ID] || null;
  }

  // Authed as the BUYING (guest) uid. Mints a single-use token bound to it.
  app.post('/api/v2/subscription/prepare-transfer', async (req, res) => {
    const uid = req.uid;
    if (!uid) return res.status(401).json({ error: 'Auth required' });
    try {
      const r = await db.execute({
        sql: 'SELECT subscription_status, subscription_product_id, subscription_expires_at FROM users WHERE id = ?',
        args: [uid],
      });
      const row = r.rows[0] || {};
      let active = row.subscription_status === 'active' || row.subscription_status === 'trial';
      let productId = row.subscription_product_id || null;
      let expiresAt = row.subscription_expires_at ?? null;
      if (!active) {
        // DB may lag the store — check RevenueCat directly.
        const ent = await rcEntitlementFor(uid).catch(() => null);
        if (ent) {
          const notExpired = !ent.expires_date || Date.now() < new Date(ent.expires_date).getTime();
          if (notExpired) {
            active = true;
            productId = productId || ent.product_identifier || null;
            if (expiresAt == null && ent.expires_date) {
              expiresAt = new Date(ent.expires_date).getTime();
            }
          }
        }
      }
      if (!active) {
        return res.status(404).json({ error: 'No active subscription to transfer' });
      }
      const now = Date.now();
      const token = crypto.randomBytes(32).toString('hex');
      await db.execute({
        sql: `INSERT INTO entitlement_transfer_tokens
              (token, from_uid, product_id, expires_at_ms, status, created_at)
              VALUES (?, ?, ?, ?, 'pending', ?)`,
        args: [token, uid, productId, now + TRANSFER_TTL_MS, now],
      });
      res.json({ ok: true, token, expires_in: TRANSFER_TTL_MS / 1000 });
    } catch (e) {
      console.error('[Transfer] prepare error:', e.message);
      res.status(500).json({ error: 'Prepare failed' });
    }
  });

  // Authed as the SURVIVING (signed-in) uid. Burns the token, mirrors the
  // subscription, grants RC promo, moves Paddle attribution forward.
  app.post('/api/v2/subscription/claim-transfer', async (req, res) => {
    const parsed = transferClaimSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const uid = req.uid;
    if (!uid) return res.status(401).json({ error: 'Auth required' });
    const now = Date.now();
    try {
      const t = await db.execute({
        sql: 'SELECT * FROM entitlement_transfer_tokens WHERE token = ?',
        args: [parsed.data.token],
      });
      const tok = t.rows[0];
      if (!tok || tok.status !== 'pending') {
        return res.status(404).json({ error: 'Unknown or used transfer token' });
      }
      if (Number(tok.expires_at_ms) <= now) {
        return res.status(410).json({ error: 'Transfer token expired' });
      }
      if (tok.from_uid === uid) {
        return res.status(400).json({ error: 'Transfer target is the buying account' });
      }
      const g = await db.execute({
        sql: 'SELECT subscription_status, subscription_product_id, subscription_expires_at FROM users WHERE id = ?',
        args: [tok.from_uid],
      });
      const guest = g.rows[0];
      const stillActive = guest && (guest.subscription_status === 'active' || guest.subscription_status === 'trial');
      if (!stillActive) {
        return res.status(410).json({ error: 'Source subscription no longer active' });
      }

      // 1) RevenueCat promotional grant on the surviving uid. Fail closed
      // (token stays pending) so the client can retry.
      let rcGranted = false;
      if (process.env.REVENUECAT_API_SECRET) {
        const grantUrl = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}/entitlements/${encodeURIComponent(RC_ENTITLEMENT_ID)}/promotional`;
        const grantRes = await fetch(grantUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ duration: promoDurationForProduct(guest.subscription_product_id) }),
        });
        if (!grantRes.ok) {
          const txt = await grantRes.text().catch(() => '');
          console.error('[Transfer] RC grant failed:', grantRes.status, txt.slice(0, 200));
          return res.status(502).json({ error: 'RevenueCat grant failed, retry later' });
        }
        rcGranted = true;
      }

      // 2) Mirror DB subscription fields (no shield re-award — the guest
      // row already got them at purchase time).
      await db.execute({ sql: 'INSERT OR IGNORE INTO users (id) VALUES (?)', args: [uid] });
      await db.execute({
        sql: `UPDATE users SET subscription_status = ?, subscription_product_id = ?, subscription_expires_at = ? WHERE id = ?`,
        args: [guest.subscription_status, guest.subscription_product_id, guest.subscription_expires_at, uid],
      });

      // 3) Move Paddle attribution forward so renewals land on the new uid.
      // Best-effort: a missed move only affects future renewals, which the
      // mirrored DB row + promo grant already cover for the current period.
      let paddleMoved = false;
      if (process.env.PADDLE_API_KEY) {
        try {
          const sub = await db.execute({
            sql: `SELECT paddle_subscription_id FROM google_external_reports
                  WHERE user_id = ? AND paddle_subscription_id IS NOT NULL
                  ORDER BY created_at DESC LIMIT 1`,
            args: [tok.from_uid],
          });
          const paddleSubId = sub.rows[0]?.paddle_subscription_id;
          if (paddleSubId) {
            const pr = await fetch(`https://api.paddle.com/subscriptions/${encodeURIComponent(paddleSubId)}`, {
              method: 'PATCH',
              headers: {
                Authorization: `Bearer ${process.env.PADDLE_API_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({ custom_data: { app_user_id: uid, appUserId: uid, uid } }),
            });
            paddleMoved = pr.ok;
            if (!pr.ok) console.warn('[Transfer] Paddle custom_data move failed:', pr.status);
          }
        } catch (e) {
          console.warn('[Transfer] Paddle move error:', e.message);
        }
      }

      await db.execute({
        sql: `UPDATE entitlement_transfer_tokens SET status = 'claimed', claimed_by_uid = ?, claimed_at = ? WHERE token = ?`,
        args: [uid, now, parsed.data.token],
      });
      console.log(`[Transfer] ${tok.from_uid} -> ${uid} (${guest.subscription_product_id}) rc=${rcGranted} paddle=${paddleMoved}`);
      res.json({ ok: true, rc_granted: rcGranted, paddle_moved: paddleMoved });
    } catch (e) {
      console.error('[Transfer] claim error:', e.message);
      res.status(500).json({ error: 'Claim failed' });
    }
  });
};
