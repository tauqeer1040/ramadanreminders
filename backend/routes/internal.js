const { pollPendingJournals } = require('../lib/ai-engine');
const { listErrors, logError } = require('../lib/error-log');

module.exports = function (app) {
  const checkSecret = (req) => {
    const secret = process.env.INTERNAL_POLL_SECRET;
    return secret && req.headers['x-internal-secret'] === secret;
  };

  app.post('/api/v2/internal/poll-ai', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    // Fire-and-forget: the worker already polls on its own interval, so this
    // endpoint is just a nudge. Return immediately so the CI cron's `curl -m 60`
    // never times out waiting on a long poll (which previously failed the job).
    pollPendingJournals().catch((error) => {
      logError({ type: 'ai_poll_cron', message: error.message, stack: error.stack, route: 'internal/poll-ai' });
    });
    return res.status(202).json({ ok: true, triggered: true });
  });

  app.get('/api/v2/internal/errors', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      const rows = await listErrors(req.query.limit);
      res.json({ errors: rows });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
