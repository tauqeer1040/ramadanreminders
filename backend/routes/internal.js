const { pollPendingJournals } = require('../lib/ai-engine');
const { listErrors } = require('../lib/error-log');

module.exports = function (app) {
  const checkSecret = (req) => {
    const secret = process.env.INTERNAL_POLL_SECRET;
    return secret && req.headers['x-internal-secret'] === secret;
  };

  app.post('/api/v2/internal/poll-ai', async (req, res) => {
    if (!checkSecret(req)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      await pollPendingJournals();
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
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
