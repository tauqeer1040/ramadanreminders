const db = require('./db');
const { encrypt, decrypt } = require('../encryption');
const { clearUserCache, clearJournalCache, clearDeckCache, clearScratchCache } = require('./cache');
const { upsertTagMapRow } = require('./tags');
const { recalculateUserMetadata } = require('./users');
const { buildInsightPrompt } = require('./prompts');
const { sanitizeInsightCards } = require('./sanitize');
const decks = require('./decks');
const fanar = require('../services/ai');

const AI_POLL_INTERVAL_MS = Math.max(5000, Number(process.env.AI_POLL_INTERVAL_MS || 60000));

function getRetryDelayMinutes(attempts) {
  if (attempts <= 1) return 5;
  if (attempts === 2) return 15;
  if (attempts === 3) return 60;
  if (attempts === 4) return 180;
  return 720;
}

let processSoonTimer = null;

function scheduleProcessSoon(delayMs = 1000) {
  if (processSoonTimer) return;
  processSoonTimer = setTimeout(async () => {
    processSoonTimer = null;
    await pollPendingJournals();
  }, delayMs);
}

async function generateFullInsight(journalText, previousJournalText) {
  const prompt = buildInsightPrompt(journalText, previousJournalText);
  return fanar.callAI(prompt);
}

let isProcessing = false;

async function pollPendingJournals() {
  if (isProcessing) return;
  isProcessing = true;

  try {
    // Early-warning counts (stuck pipeline visibility).
    const s = await db.execute({
      sql: `SELECT ai_status AS st, COUNT(*) AS n FROM journal_entries
            WHERE ai_status IN ('pending','processing','failed')
            GROUP BY ai_status`,
      args: [],
    });
    const parts = s.rows.map((r) => `${r.st}=${r.n}`);
    if (parts.length) console.log(`[AI] queue: ${parts.join(' ')}`);
  } catch (_) {
    // counts are best-effort; never block the poll
  }

  try {
    const pending = await db.execute(
      `
        SELECT id, user_id, content, ai_attempts, created_at
        FROM journal_entries
        WHERE
          (
            ai_status = 'pending'
            AND COALESCE(ai_next_retry_at, created_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
          )
          OR (
            ai_status = 'failed'
            AND COALESCE(ai_next_retry_at, created_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
            AND COALESCE(ai_attempts, 0) < 5
          )
        ORDER BY
          CASE WHEN ai_status = 'pending' THEN 0 ELSE 1 END,
          created_at ASC
        LIMIT 3
      `
    );

    for (const journal of pending.rows) {
      await db.execute({
        sql: `
          UPDATE journal_entries
          SET
            ai_status = 'processing',
            ai_attempts = COALESCE(ai_attempts, 0) + 1,
            ai_last_error = NULL,
            ai_next_retry_at = DATETIME('now', '+15 minutes')
          WHERE id = ?
        `,
        args: [journal.id],
      });

      try {
        try {
          await decks.ensureBuildingDeck(journal.user_id, journal.id);
        } catch (_) {}
        const prevResult = await db.execute({
          sql: `
            SELECT j.content
            FROM journal_entries j
            JOIN journal_ai a ON j.id = a.journal_id
            WHERE j.user_id = ? AND j.id != ?
            ORDER BY j.created_at DESC
            LIMIT 1
          `,
          args: [journal.user_id, journal.id],
        });

        const previousJournalText = decrypt(prevResult.rows[0]?.content || null, journal.user_id);
        const decryptedContent = decrypt(journal.content, journal.user_id);
        const ai = await generateFullInsight(decryptedContent, previousJournalText);
        if (Array.isArray(ai?.cards)) ai.cards = sanitizeInsightCards(ai.cards);
        if (!Array.isArray(ai?.cards) || ai.cards.length < 3 || ai.cards.length > 4) {
          throw new Error(`AI returned ${Array.isArray(ai?.cards) ? ai.cards.length : 0} cards, expected 3-4`);
        }
        // Pre-enrich on the write path so reads never block on alquran.cloud.
        // Best-effort: enrichment failure still serves the deck (audio optional).
        try {
          const surahCard = ai.cards.find((c) => c && c.type === 'surah_guidance');
          await decks.enrichSurahCard(surahCard);
        } catch (_) {}
        const fullJson = JSON.stringify(ai);
        const encryptedSummary = encrypt(fullJson, journal.user_id);
        const card1 = ai.cards?.[0] || {};

        const statements = [
          {
            sql: `
              INSERT INTO journal_ai (
                id, journal_id, user_id, summary, tags, quote, reference, suggested_tasks, task_tags, updated_at
              )
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
              ON CONFLICT(journal_id) DO UPDATE SET
                user_id = excluded.user_id,
                summary = excluded.summary,
                tags = excluded.tags,
                quote = excluded.quote,
                reference = excluded.reference,
                suggested_tasks = excluded.suggested_tasks,
                task_tags = excluded.task_tags,
                updated_at = CURRENT_TIMESTAMP
            `,
            args: [
              `ai_${journal.id}`,
              journal.id,
              journal.user_id,
              encryptedSummary,
              '[]',
              card1.quote || '',
              card1.reference || '',
              '[]',
              '[]',
            ],
          },
          {
            sql: "UPDATE journal_entries SET ai_status = 'completed' WHERE id = ?",
            args: [journal.id],
          },
        ];

        const tags = ai.cards
            ?.map((c) => c.reference || c.storyReference || '')
            .filter(Boolean) ?? [];
        const taskTags = [ai.cards?.[2]?.taskTitle || ''].filter(Boolean);

        await db.batch(statements, 'write');
        for (const tag of tags) {
          await upsertTagMapRow('user_tag_maps', journal.user_id, tag, journal.id, journal.created_at);
        }
        for (const tag of taskTags) {
          await upsertTagMapRow('user_task_tag_maps', journal.user_id, tag, journal.id, journal.created_at);
        }
        // Publish the serve-ready deck (supersedes prior active decks for this
        // journal; revealed history stays frozen and re-queues by journal time).
        try {
          await decks.completeDeck(journal.user_id, journal.id, journal.created_at, ai.cards);
        } catch (deckError) {
          console.error(`[POLLER DECK ERROR] ${journal.id}: ${deckError.message}`);
        }
        await recalculateUserMetadata(journal.user_id);
        clearUserCache(journal.user_id);
        clearJournalCache(journal.id);
        clearDeckCache(journal.user_id);
        clearScratchCache(journal.user_id);
      } catch (error) {
        console.error(`[POLLER ERROR] ${journal.id}: ${error.message}`);
        require('./error-log').logError({
          type: 'ai_poll_journal',
          message: error.message,
          stack: error.stack,
          uid: journal.user_id,
          route: 'internal/poll-ai',
          method: 'POST',
        });
        const attemptNumber = Number(journal.ai_attempts || 0) + 1;
        const retryDelayMinutes = getRetryDelayMinutes(attemptNumber);
        if (attemptNumber >= 5) {
          // Slow lane: keep retrying once daily instead of dying forever.
          // Resetting attempts to 4 keeps the row eligible under the
          // poller's attempts < 5 predicate.
          await db.execute({
            sql: `
              UPDATE journal_entries
              SET
                ai_status = 'failed',
                ai_last_error = ?,
                ai_attempts = 4,
                ai_next_retry_at = DATETIME('now', '+24 hours')
              WHERE id = ?
            `,
            args: [`[slow-lane] ${error.message.slice(0, 480)}`, journal.id],
          });
          console.warn(`[AI] ${journal.id} moved to slow-lane daily retry`);
        } else {
          await db.execute({
            sql: `
              UPDATE journal_entries
              SET
                ai_status = 'failed',
                ai_last_error = ?,
                ai_next_retry_at = DATETIME('now', ?)
              WHERE id = ?
            `,
            args: [error.message.slice(0, 500), `+${retryDelayMinutes} minutes`, journal.id],
          });
        }
        clearJournalCache(journal.id);
      }
    }
  } catch (error) {
    console.error('[POLLER DB ERROR]', error.message);
    require('./error-log').logError({
      type: 'ai_poll_db',
      message: error.message,
      stack: error.stack,
    });
  } finally {
    isProcessing = false;
  }
}

function startPolling() {
  // Provider visibility: Fanar is first priority, OpenRouter is fallback.
  // Log key presence (never values) so silent-fallback is diagnosable.
  console.log(
    `[AI] providers: fanar=${process.env.FANAR_API_KEY ? 'key-set' : 'MISSING'} ` +
    `openrouter=${process.env.OPENROUTER_API_KEY ? 'key-set' : 'MISSING'}`
  );  // Reaper: rows left in 'processing' by a crash/restart (lease expired)
  // go back to pending instead of stalling forever. At startup no worker
  // is legitimately processing, so any expired lease is stale.
  db.execute({
    sql: `UPDATE journal_entries SET ai_status = 'pending', ai_next_retry_at = NULL
          WHERE ai_status = 'processing'
          AND (ai_next_retry_at IS NULL OR ai_next_retry_at <= CURRENT_TIMESTAMP)`,
    args: [],
  }).then(
    (r) => {
      const n = Number(r.rowsAffected || 0);
      if (n > 0) console.warn(`[AI] reaper: ${n} stuck processing row(s) back to pending`);
    },
    (e) => console.error('[AI] reaper failed:', e.message),
  );
  setInterval(pollPendingJournals, AI_POLL_INTERVAL_MS);
}

module.exports = { getRetryDelayMinutes, scheduleProcessSoon, generateFullInsight, pollPendingJournals, startPolling };
