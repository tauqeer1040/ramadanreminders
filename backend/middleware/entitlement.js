const { resolveEntitlement } = require('../lib/entitlement');

/**
 * Server-side counterpart of the client's expired wall.
 *
 * Denies when the backend can positively say the trial is over and there is
 * no store entitlement. Every other outcome (RC outage, DB blip, brand-new
 * user, unknown state) reaches `next()` — a bad gate must never lock a paying
 * user out of their own content, and the expensive routes it protects are
 * exactly the ones a bypassed client would hammer.
 */
function requireEntitlement() {
  return async (req, res, next) => {
    if (!req.uid) {
      return res.status(401).json({ error: 'Auth required' });
    }
    try {
      const verdict = await resolveEntitlement(req.uid);
      if (verdict.active) return next();
      console.warn(
        `[Entitlement] denied uid=${req.uid} route=${req.path} reason=${verdict.reason}`,
      );
      return res.status(402).json({
        error: 'subscription_required',
        reason: verdict.reason,
        daysRemaining: 0,
        message: 'Your free trial has ended. Subscribe to Meowmin Max to keep going.',
      });
    } catch (e) {
      console.error('[Entitlement] gate error (fail-open):', e.message);
      return next();
    }
  };
}

module.exports = { requireEntitlement };
