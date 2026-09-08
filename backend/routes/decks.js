const db = require('../lib/db');
const decks = require('../lib/decks');
const { clearDeckCache, clearScratchCache } = require('../lib/cache');
const { deckRevealSchema } = require('../lib/validation');

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

function dayParam(req) {
  const raw = String(req.query.day || '').slice(0, 10);
  if (DAY_RE.test(raw)) return raw;
  return new Date().toISOString().slice(0, 10);
}

module.exports = function (app) {
  // Serve today's deck: sticky served -> oldest unread ready -> suggested fallback.
  // Exactly 1 deck per local day; prefetch never marks served (see /next).
  app.get('/api/v2/user/:uid/decks/today', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    try {
      const payload = await decks.getTodayDeck(req.uid, dayParam(req));
      res.json(payload);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Prefetch helper: oldest ready deck excluding the current one. Read-only.
  app.get('/api/v2/user/:uid/decks/next', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    try {
      const exclude = String(req.query.excludeDeckId || req.query.exclude || '').trim() || null;
      const payload = await decks.getNextDeck(req.uid, exclude);
      if (!payload) return res.json({ deckId: null, insightCards: [], queueDepth: 0, fallback: false });
      res.json(payload);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Idempotent reveal ack: only a full card-id set flips served -> revealed.
  app.post('/api/v2/user/:uid/decks/:deckId/revealed', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const parsed = deckRevealSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    try {
      const result = await decks.ackRevealed(req.uid, req.params.deckId, parsed.data.cardIds || []);
      clearDeckCache(req.uid);
      clearScratchCache(req.uid);
      res.json(result);
    } catch (error) {
      res.status(error.statusCode || 500).json({ error: error.message });
    }
  });

  // Per-journal status for editor/history pending UI + queue position.
  app.get('/api/v2/journal/:id/insight', async (req, res) => {
    try {
      const payload = await decks.getJournalInsight(req.uid, req.params.id);
      res.json(payload);
    } catch (error) {
      res.status(error.statusCode || 500).json({ error: error.message });
    }
  });

  // Deck health for ops: queue depth, stuck building, recent failures, plus
  // the goal metric — journals still waiting for insights past grace.
  app.get('/api/v2/user/:uid/decks/health', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    try {
      const [ready, served, building, failed, stale, done24, made24] = await Promise.all([
        db.execute({ sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND status = 'ready'`, args: [req.uid] }),
        db.execute({ sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND status = 'served'`, args: [req.uid] }),
        db.execute({ sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND status = 'building'`, args: [req.uid] }),
        db.execute({
          sql: `SELECT COUNT(*) AS n FROM journal_entries WHERE user_id = ? AND ai_status = 'failed'`,
          args: [req.uid],
        }),
        db.execute({
          sql: `SELECT COUNT(*) AS n,
                  MAX(CAST((strftime('%s','now') - strftime('%s', COALESCE(ai_next_retry_at, created_at))) / 60 AS INTEGER)) AS oldest_min
                FROM journal_entries
                WHERE user_id = ? AND ai_status = 'pending'
                  AND (ai_next_retry_at IS NULL OR ai_next_retry_at <= DATETIME('now', '-45 minutes'))`,
          args: [req.uid],
        }),
        db.execute({
          sql: `SELECT COUNT(*) AS n FROM journal_ai WHERE user_id = ? AND updated_at > DATETIME('now', '-24 hours')`,
          args: [req.uid],
        }),
        db.execute({
          sql: `SELECT COUNT(*) AS n FROM journal_entries WHERE user_id = ? AND created_at > DATETIME('now', '-24 hours')`,
          args: [req.uid],
        }),
      ]);
      res.json({
        ready: Number(ready.rows[0]?.n || 0),
        served: Number(served.rows[0]?.n || 0),
        building: Number(building.rows[0]?.n || 0),
        failed: Number(failed.rows[0]?.n || 0),
        pendingStale: Number(stale.rows[0]?.n || 0),
        oldestPendingMin: stale.rows[0]?.oldest_min == null ? 0 : Number(stale.rows[0].oldest_min),
        completed24h: Number(done24.rows[0]?.n || 0),
        journals24h: Number(made24.rows[0]?.n || 0),
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
