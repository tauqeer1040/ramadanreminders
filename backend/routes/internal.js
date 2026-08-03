const { pollPendingJournals } = require('../lib/ai-engine');

module.exports = function (app) {
  app.post('/api/v2/internal/poll-ai', async (req, res) => {
    const secret = process.env.INTERNAL_POLL_SECRET;
    if (!secret || req.headers['x-internal-secret'] !== secret) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      await pollPendingJournals();
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
