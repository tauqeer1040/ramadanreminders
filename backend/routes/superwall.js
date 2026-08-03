const crypto = require('crypto');
const db = require('../lib/db');

module.exports = function (app) {
  app.post('/api/v2/superwall-webhook', async (req, res) => {
    try {
      const signature = req.headers['x-signature'];
      const rawBody = req.rawBody;
      const eventId = req.body?.data?.id;

      if (!eventId) {
        return res.status(400).json({ error: 'Missing event id' });
      }

      if (!process.env.SUPERWALL_WEBHOOK_SECRET) {
        console.warn('[SUPERWALL WEBHOOK] Secret not configured');
        return res.status(500).json({ error: 'Webhook secret not configured' });
      }

      const expectedSig = crypto
        .createHmac('sha256', process.env.SUPERWALL_WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

      if (signature !== expectedSig) {
        console.warn('[SUPERWALL WEBHOOK] Invalid signature');
        return res.status(401).json({ error: 'Invalid signature' });
      }

      // Idempotency check
      const existing = await db.execute({
        sql: 'SELECT 1 FROM webhook_events WHERE event_id = ?',
        args: [eventId],
      });
      if (existing.rows.length > 0) {
        console.log(`[SUPERWALL WEBHOOK] Duplicate event ${eventId}, skipping`);
        return res.status(200).json({ received: true, deduped: true });
      }

      const event = req.body;
      const { type, data } = event;
      const eventData = data;

      console.log(`[SUPERWALL WEBHOOK] Event: ${type} | Product: ${eventData.productId} | User: ${eventData.originalAppUserId}`);

      const uid = eventData.originalAppUserId;
      if (!uid) return res.status(200).json({ received: true });

      const now = Date.now();

      switch (type) {
        case 'initial_purchase': {
          const isTrial = eventData.periodType === 'TRIAL';
          const status = isTrial ? 'trial' : 'active';
          const expiresAt = eventData.expirationAt;
          await db.execute({
            sql: `UPDATE users SET
              subscription_status = ?,
              subscription_product_id = ?,
              subscription_expires_at = ?,
              subscription_trial_started_at = COALESCE(subscription_trial_started_at, ?)
            WHERE id = ?`,
            args: [status, eventData.productId, expiresAt, isTrial ? now : null, uid],
          });
          break;
        }
        case 'renewal': {
          await db.execute({
            sql: `UPDATE users SET
              subscription_status = ?,
              subscription_product_id = ?,
              subscription_expires_at = ?
            WHERE id = ?`,
            args: ['active', eventData.productId, eventData.expirationAt, uid],
          });
          if (eventData.isTrialConversion) {
            console.log(`[SUPERWALL WEBHOOK] Trial converted to paid for user ${uid}`);
          }
          break;
        }
        case 'cancellation': {
          await db.execute({
            sql: `UPDATE users SET subscription_status = 'cancelled' WHERE id = ?`,
            args: [uid],
          });
          break;
        }
        case 'uncancellation': {
          await db.execute({
            sql: `UPDATE users SET subscription_status = 'active' WHERE id = ?`,
            args: [uid],
          });
          break;
        }
        case 'expiration': {
          await db.execute({
            sql: `UPDATE users SET subscription_status = 'expired' WHERE id = ?`,
            args: [uid],
          });
          break;
        }
        case 'billing_issue': {
          console.log(`[SUPERWALL WEBHOOK] Billing issue for user ${uid}: ${eventData.cancelReason || 'unknown'}`);
          break;
        }
        case 'product_change': {
          await db.execute({
            sql: `UPDATE users SET
              subscription_product_id = ?,
              subscription_expires_at = ?
            WHERE id = ?`,
            args: [eventData.newProductId, eventData.expirationAt, uid],
          });
          break;
        }
        case 'subscription_paused': {
          await db.execute({
            sql: `UPDATE users SET subscription_status = 'paused' WHERE id = ?`,
            args: [uid],
          });
          break;
        }
        case 'non_renewing_purchase': {
          console.log(`[SUPERWALL WEBHOOK] Non-renewing purchase by user ${uid}: ${eventData.productId}`);
          break;
        }
      }

      // Record processed event for idempotency
      await db.execute({
        sql: 'INSERT OR IGNORE INTO webhook_events (event_id, type, uid, processed_at) VALUES (?, ?, ?, ?)',
        args: [eventId, type, uid, now],
      });

      res.status(200).json({ received: true });
    } catch (error) {
      console.error('[SUPERWALL WEBHOOK] Error:', error.message);
      res.status(500).json({ error: 'Webhook processing failed' });
    }
  });
};
