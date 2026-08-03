const db = require('../lib/db');
const { subscriptionSyncSchema } = require('../lib/validation');

module.exports = function (app) {
  // No-webhook fix: client sends subscription info after RevenueCat purchase/restore.
  // Server verifies by calling RevenueCat REST API before trusting the data.
  app.post('/api/v2/subscription/sync', async (req, res) => {
    const parsed = subscriptionSyncSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { appUserId, productId, status, expiresAt, periodType } = parsed.data;

    // Optional: verify with RevenueCat REST API
    if (process.env.REVENUECAT_API_SECRET) {
      try {
        const verifyUrl = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`;
        const rcRes = await fetch(verifyUrl, {
          headers: { Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}` },
        });
        if (!rcRes.ok) throw new Error(`RevenueCat verify failed (${rcRes.status})`);
        const rcResponse = await rcRes.json();

        const entitlement = rcResponse?.subscriber?.entitlements?.['premium'];
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
      res.json({ received: true, verified: true });
    } catch (error) {
      console.error('[Subscription Sync] DB error:', error.message);
      res.status(500).json({ error: 'Sync failed' });
    }
  });
};
