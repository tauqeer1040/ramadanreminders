const { resolveEntitlement } = require('../lib/entitlement');

/**
 * Client-facing entitlement verdict — the source of truth the app's expired
 * wall reads (instead of trusting its own local trial clock).
 */
module.exports = function (app) {
  app.get('/api/v2/entitlement', async (req, res) => {
    try {
      const verdict = await resolveEntitlement(req.uid);
      res.json(verdict);
    } catch (e) {
      console.error('[Entitlement] route error:', e.message);
      res.status(500).json({ error: 'Failed to resolve entitlement' });
    }
  });
};
