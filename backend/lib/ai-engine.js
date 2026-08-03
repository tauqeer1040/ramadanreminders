const db = require('./db');
const { encrypt, decrypt } = require('../encryption');
const { clearUserCache, clearJournalCache } = require('./cache');
const { upsertTagMapRow } = require('./tags');
const { recalculateUserMetadata } = require('./users');
const { buildInsightPrompt } = require('./prompts');
const { sanitizeInsightCards } = require('./sanitize');
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
    const pending = await db.execute(
      `
        SELECT id, user_id, content, ai_attempts, created_at
        FROM journal_entries
        WHERE
          (
            ai_status = 'pending'
            AND COALESCE(ai_next_retry_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
          )
          OR (
            ai_status = 'failed'
            AND COALESCE(ai_next_retry_at, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP
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
            ai_next_retry_at = NULL
          WHERE id = ?
        `,
        args: [journal.id],
      });

      try {
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
        await recalculateUserMetadata(journal.user_id);
        clearUserCache(journal.user_id);
        clearJournalCache(journal.id);
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
  setInterval(pollPendingJournals, AI_POLL_INTERVAL_MS);
}

module.exports = { getRetryDelayMinutes, scheduleProcessSoon, generateFullInsight, pollPendingJournals, startPolling };
