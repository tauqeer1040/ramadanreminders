const crypto = require('crypto');
const db = require('../lib/db');
const rc = require('../lib/revenuecat');
const { subscriptionSyncSchema, transferLifetimeSchema, transferClaimSchema } = require('../lib/validation');
const { shieldsForProduct } = require('../lib/shields');

module.exports = function (app) {
  app.post('/api/v2/subscription/sync', async (req, res) => {
    const parsed = subscriptionSyncSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { appUserId, productId, status, expiresAt, periodType } = parsed.data;

    // RevenueCat owns the purchase, so when it can be reached it is the source
    // of truth for every field — the client's report is only a trigger. A
    // client-claimed 'active' that the store does not confirm is ignored
    // (previously it was logged and then written anyway, which let an
    // authenticated client grant itself Max).
    let verified = false;
    let effProductId = productId;
    let effStatus = status;
    let effExpiresAt = expiresAt;

    if (rc.rcConfigured()) {
      try {
        // v2: the customer's active_entitlements list only contains entries
        // that are currently active; our entitlement is matched by internal id.
        const entitlements = await rc.rcActiveEntitlements(appUserId);
        const entitlement = entitlements.find(
          (e) => e.entitlement_id === rc.entitlementId(),
        );
        if (!entitlement) {
          console.warn(`[Subscription Sync] No store entitlement for ${appUserId} — ignoring claim`);
          return res.status(200).json({ received: true, verified: false, reason: 'no_entitlement' });
        }

        // active_entitlements items carry no product id — resolve it from the
        // subscriptions (or one-time purchases, for lifetime) so the DB keeps
        // recording the store's plan rather than the client's claim.
        let storeProductId = null;
        try {
          const subs = await rc.rcSubscriptions(appUserId);
          const activeSubs = subs.filter(
            (s) => s.expires_at == null || s.expires_at > Date.now() || s.auto_renewal_status === 'is_active',
          );
          const best = activeSubs.sort(
            (a, b) => (b.expires_at ?? Infinity) - (a.expires_at ?? Infinity),
          )[0];
          storeProductId = best?.product_id ?? null;
        } catch (_) {}
        if (!storeProductId) {
          try {
            const purchases = await rc.rcPurchases(appUserId);
            storeProductId = purchases[0]?.product_id ?? null;
          } catch (_) {}
        }

        const expiresMs = entitlement.expires_at != null ? Number(entitlement.expires_at) : null;
        const serverIsActive = expiresMs != null && Number.isFinite(expiresMs)
          ? Date.now() < expiresMs
          : true; // no expiry on an active entitlement = lifetime/unlimited

        verified = true;
        effProductId = storeProductId || productId;
        effStatus = serverIsActive ? 'active' : 'expired';
        effExpiresAt = expiresMs != null && Number.isFinite(expiresMs) ? expiresMs : null;

        const reportedIsActive = status === 'active' || status === 'trial';
        if (serverIsActive !== reportedIsActive) {
          console.warn(
            `[Subscription Sync] Claim overridden for ${appUserId}: store=${serverIsActive} (${effProductId}) claimed=${reportedIsActive} (${productId})`,
          );
        }
      } catch (e) {
        console.error('[Subscription Sync] Verification failed:', e.message);
        return res.status(200).json({ received: true, verified: false, reason: 'verify_failed' });
      }
    }

    const now = Date.now();
    try {
      // The client syncs on every launch (RevenueCat identify), so granting on
      // each call inflated the balance without bound — a yearly subscriber
      // collected another 72 shields per cold start. `plan_shields_product`
      // records which plan this account has already been credited for, making
      // the grant once-per-plan (a new plan earns its own allowance).
      const existing = await db.execute({
        sql: 'SELECT plan_shields_product FROM users WHERE id = ?',
        args: [appUserId],
      });
      const grantedFor = existing.rows[0]?.plan_shields_product || null;

      // The sync can be the first thing we ever hear about this uid.
      await db.execute({
        sql: 'INSERT OR IGNORE INTO users (id) VALUES (?)',
        args: [appUserId],
      });

      await db.execute({
        sql: `UPDATE users SET
          subscription_status = ?,
          subscription_product_id = ?,
          subscription_expires_at = ?,
          subscription_trial_started_at = COALESCE(subscription_trial_started_at, CASE WHEN ? = 'trial' THEN ? ELSE NULL END)
        WHERE id = ?`,
        args: [effStatus, effProductId, effExpiresAt || null, periodType, now, appUserId],
      });

      // Award shields once per plan.
      if (effStatus === 'active' || effStatus === 'trial') {
        const shields = shieldsForProduct(effProductId);
        const alreadyGranted =
          grantedFor != null && String(grantedFor) === String(effProductId || '');
        if (shields > 0 && !alreadyGranted) {
          await db.execute({
            sql: `UPDATE users SET shield_balance = COALESCE(shield_balance, 0) + ?,
                                  plan_shields_product = ? WHERE id = ?`,
            args: [shields, String(effProductId || ''), appUserId],
          });
          console.log(`[Subscription Sync] Awarded ${shields} shields to ${appUserId} for ${effProductId}`);
        }
        // Value-recap email, 24h delayed (stats settle). Deduped 30d;
        // skipped when no email is on file (welcome sheet captures later).
        try {
          const { enqueueMaxRecap } = require('../lib/email-queue');
          await enqueueMaxRecap(appUserId);
        } catch (e) {
          console.warn('[Subscription Sync] recap enqueue failed:', e.message);
        }
      }

      res.json({ received: true, verified, productId: effProductId, status: effStatus });
    } catch (error) {
      console.error('[Subscription Sync] DB error:', error.message);
      res.status(500).json({ error: 'Sync failed' });
    }
  });

  // Re-trigger the recap email after the welcome sheet captures an email
  // (purchase-time enqueue skips users with no address on file).
  app.post('/api/v2/subscription/recap-email', async (req, res) => {
    try {
      const { enqueueMaxRecap } = require('../lib/email-queue');
      const id = await enqueueMaxRecap(req.uid);
      return res.json({ queued: id != null });
    } catch (e) {
      console.error('[Subscription] recap-email failed:', e.message);
      return res.status(500).json({ error: 'Failed to queue recap email' });
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
  const TRANSFER_TTL_MS = 10 * 60 * 1000;

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

  // v2 grants take an absolute expiry (ms since epoch). Map the legacy
  // duration enums to ms; lifetime = far future (the grant endpoint requires
  // a number, so use ~100 years).
  const DAY_MS = 24 * 60 * 60 * 1000;
  function promoDurationMs(duration) {
    switch (duration) {
      case 'lifetime': return Date.now() + 100 * 365 * DAY_MS;
      case 'yearly': return Date.now() + 365 * DAY_MS;
      case '6_month': return Date.now() + 182 * DAY_MS;
      case '3_month': return Date.now() + 91 * DAY_MS;
      case '2_month': return Date.now() + 61 * DAY_MS;
      default: return Date.now() + 30 * DAY_MS;
    }
  }

  async function rcEntitlementFor(appUserId) {
    if (!rc.rcConfigured()) return null;
    try {
      const entitlements = await rc.rcActiveEntitlements(appUserId);
      const ent = entitlements.find((e) => e.entitlement_id === rc.entitlementId());
      if (!ent) return null;
      // Mirror the old shape ({ expires_date, product_identifier }) so the
      // prepare-transfer consumer below stays unchanged.
      return {
        expires_date: ent.expires_at != null ? new Date(Number(ent.expires_at)).toISOString() : null,
        product_identifier: null,
      };
    } catch (_) {
      return null;
    }
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
      if (rc.rcConfigured()) {
        // v2 grant takes an absolute expiry (ms) instead of a duration enum.
        const grantMs = promoDurationMs(promoDurationForProduct(guest.subscription_product_id));
        const granted = await rc.rcGrantEntitlement(uid, rc.entitlementId(), grantMs);
        if (!granted) {
          console.error('[Transfer] RC grant failed: (non-ok response)');
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

// Exposed for the shield-award unit test.
module.exports.shieldsForProduct = shieldsForProduct;
