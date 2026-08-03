const db = require('../lib/db');
const { getCache, clearUserCache, clearJournalCache } = require('../lib/cache');
const { decrypt } = require('../encryption');
const { upsertUser, recalculateUserMetadata } = require('../lib/users');
const { upsertJournal, buildInsightCardsFromRows, loadSimilarMatchesForJournal } = require('../lib/journals');
const { scheduleProcessSoon } = require('../lib/ai-engine');
const { buildDailyContent } = require('../lib/quran');
const { syncJournalsSchema, createJournalSchema } = require('../lib/validation');

module.exports = function (app, apiLimiter) {
  app.get('/api/v2/user/:uid/journals', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const uid = req.uid;
    const { limit, status } = req.query;
    try {
      const queryArgs = [uid];
      let sql = `
        SELECT
          j.id,
          j.content,
          j.created_at,
          j.ai_status,
          a.summary,
          a.tags,
          a.quote,
          a.reference,
          a.suggested_tasks,
          a.task_tags
        FROM journal_entries j
        LEFT JOIN journal_ai a ON j.id = a.journal_id
        WHERE j.user_id = ?
      `;

      if (status) {
        sql += ' AND j.ai_status = ?';
        queryArgs.push(String(status));
      }

      sql += ' ORDER BY j.created_at DESC';

      const parsedLimit = Number(limit);
      if (Number.isFinite(parsedLimit) && parsedLimit > 0) {
        sql += ' LIMIT ?';
        queryArgs.push(Math.min(parsedLimit, 50));
      }

      const result = await db.execute({ sql, args: queryArgs });

      res.json(
        result.rows.map((row) => ({
          id: row.id,
          content: decrypt(row.content, uid),
          createdAt: row.created_at,
          status: row.ai_status,
          summary: row.summary ? decrypt(row.summary, uid) : null,
          quote: row.quote || null,
          reference: row.reference || null,
          tags: JSON.parse(row.tags || '[]'),
          suggestedTasks: JSON.parse(row.suggested_tasks || '[]'),
          taskTags: JSON.parse(row.task_tags || '[]'),
        }))
      );
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/v2/journals/sync', apiLimiter, async (req, res) => {
    const parsed = syncJournalsSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { displayName, email, journals } = parsed.data;
    const uid = req.uid;

    try {
      await upsertUser(uid, displayName, email);

      let syncedCount = 0;
      let newCount = 0;
      for (const journal of journals) {
        if (!journal?.id || !journal?.text || !String(journal.text).trim()) continue;
        const existing = await db.execute({ sql: 'SELECT 1 FROM journal_entries WHERE id = ?', args: [journal.id] });
        const isNew = existing.rows.length === 0;
        await upsertJournal(uid, { id: journal.id, text: String(journal.text).trim() });
        syncedCount += 1;
        if (isNew) newCount += 1;
      }

      await recalculateUserMetadata(uid);
      clearUserCache(uid);
      if (syncedCount > 0) {
        if (newCount > 0) {
          await db.execute({ sql: 'UPDATE users SET stars = COALESCE(stars, 0) + ? WHERE id = ?', args: [newCount * 10, uid] });
        }
        scheduleProcessSoon();
      }

      const starResult = await db.execute({ sql: 'SELECT stars FROM users WHERE id = ?', args: [uid] });
      const stars = starResult.rows[0]?.stars ?? 0;

      res.status(202).json({
        success: true,
        uid,
        syncedCount,
        newCount,
        stars,
        status: syncedCount > 0 ? 'pending' : 'noop',
      });
    } catch (error) {
      console.error('[SYNC ERROR]', error.message);
      res.status(500).json({ error: 'Database sync failed' });
    }
  });

  app.post('/api/v2/journal', apiLimiter, async (req, res) => {
    const parsed = createJournalSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { id, text } = parsed.data;
    const uid = req.uid;

    try {
      const existing = await db.execute({ sql: 'SELECT 1 FROM journal_entries WHERE id = ?', args: [id] });
      const isNew = existing.rows.length === 0;

      await upsertUser(uid);
      await upsertJournal(uid, { id, text: String(text).trim() });
      await recalculateUserMetadata(uid);
      clearUserCache(uid);
      scheduleProcessSoon();

      if (isNew) {
        await db.execute({ sql: 'UPDATE users SET stars = COALESCE(stars, 0) + 10 WHERE id = ?', args: [uid] });
      }

      const starResult = await db.execute({ sql: 'SELECT stars FROM users WHERE id = ?', args: [uid] });
      const stars = starResult.rows[0]?.stars ?? 0;

      res.status(202).json({ success: true, id, status: 'pending', stars });
    } catch (error) {
      console.error('[API] DB Save Error:', error.message);
      res.status(500).json({ error: 'Database write failed' });
    }
  });

  app.get('/api/v2/journal/:id', async (req, res) => {
    const { id } = req.params;
    const cached = getCache(`journal:${id}`);
    if (cached) return res.json(cached);

    try {
      const result = await db.execute({
        sql: `
          SELECT
            j.id,
            j.user_id,
            j.content,
            j.created_at,
            j.ai_status,
            j.ai_attempts,
            j.ai_last_error,
            j.ai_next_retry_at,
            a.summary,
            a.tags,
            a.quote,
            a.reference,
            a.suggested_tasks,
            a.task_tags
          FROM journal_entries j
          LEFT JOIN journal_ai a ON j.id = a.journal_id
          WHERE j.id = ?
        `,
        args: [id],
      });

      if (!result.rows.length) return res.status(404).json({ error: 'Journal not found' });

      const row = result.rows[0];
      if (row.user_id !== req.uid) return res.status(403).json({ error: 'Forbidden' });

      const payload = {
        id: row.id,
        userId: row.user_id,
        text: decrypt(row.content, row.user_id),
        createdAt: row.created_at,
        status: row.ai_status,
        aiAttempts: row.ai_attempts,
        aiLastError: row.ai_last_error,
        aiNextRetryAt: row.ai_next_retry_at,
        insight: row.summary
          ? {
              summary: decrypt(row.summary, row.user_id),
              tags: JSON.parse(row.tags || '[]'),
              quote: row.quote,
              reference: row.reference,
              suggestedTasks: JSON.parse(row.suggested_tasks || '[]'),
              taskTags: JSON.parse(row.task_tags || '[]'),
            }
          : null,
      };

      res.json(payload);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/tags', async (_req, res) => {
    try {
      res.json((await db.execute('SELECT * FROM tag_index')).rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/task-tags', async (_req, res) => {
    try {
      res.json((await db.execute('SELECT * FROM task_tag_index')).rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/user/:uid/tag-maps', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const uid = req.uid;
    try {
      const [reflectionMaps, taskMaps] = await Promise.all([
        db.execute({
          sql: 'SELECT tag, journal_ids, journal_refs, updated_at FROM user_tag_maps WHERE user_id = ? ORDER BY tag ASC',
          args: [uid],
        }),
        db.execute({
          sql: 'SELECT tag, journal_ids, journal_refs, updated_at FROM user_task_tag_maps WHERE user_id = ? ORDER BY tag ASC',
          args: [uid],
        }),
      ]);

      res.json({
        reflections: reflectionMaps.rows.map((row) => ({
          tag: row.tag,
          journalIds: JSON.parse(row.journal_ids || '[]'),
          journalRefs: JSON.parse(row.journal_refs || '[]'),
          updatedAt: row.updated_at,
        })),
        tasks: taskMaps.rows.map((row) => ({
          tag: row.tag,
          journalIds: JSON.parse(row.journal_ids || '[]'),
          journalRefs: JSON.parse(row.journal_refs || '[]'),
          updatedAt: row.updated_at,
        })),
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/user/:uid/daily-content', async (req, res) => {
    if (req.params.uid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    const uid = req.uid;
    const dayKey = String(req.query.day || new Date().toISOString().slice(0, 10));
    try {
      const payload = await buildDailyContent(uid, dayKey);
      res.json(payload);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/journal/:id/similar', async (req, res) => {
    const { id } = req.params;
    try {
      const journalResult = await db.execute({
        sql: 'SELECT id, user_id, created_at FROM journal_entries WHERE id = ?',
        args: [id],
      });
      if (!journalResult.rows.length) {
        return res.status(404).json({ error: 'Journal not found' });
      }

      const journal = journalResult.rows[0];
      if (journal.user_id !== req.uid) {
        return res.status(403).json({ error: 'Forbidden' });
      }
      const related = await loadSimilarMatchesForJournal(journal.user_id, id);

      res.json({
        journalId: journal.id,
        createdAt: journal.created_at,
        reflectionTags: related.reflectionTags,
        taskTags: related.taskTags,
        similarReflections: related.similarReflections,
        similarTasks: related.similarTasks,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/v2/journals/retry-failed', apiLimiter, async (req, res) => {
    const uid = req.uid;

    try {
      const failedRows = await db.execute({
        sql: `
          SELECT id
          FROM journal_entries
          WHERE user_id = ? AND ai_status = 'failed' AND COALESCE(ai_attempts, 0) < 5
        `,
        args: [uid],
      });
      const result = await db.execute({
        sql: `
          UPDATE journal_entries
          SET
            ai_status = 'pending',
            ai_next_retry_at = NULL
          WHERE user_id = ? AND ai_status = 'failed' AND COALESCE(ai_attempts, 0) < 5
        `,
        args: [uid],
      });
      for (const row of failedRows.rows) {
        clearJournalCache(row.id);
      }
      clearUserCache(uid);
      scheduleProcessSoon();
      res.json({ success: true, queued: Number(result.rowsAffected || 0) });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
