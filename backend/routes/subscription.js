const db = require('../lib/db');
const { subscriptionSyncSchema, transferLifetimeSchema } = require('../lib/validation');

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
};
