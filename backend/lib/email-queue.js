// Outbox email queue: screen-views enqueue instantly, a worker delivers
// with backoff. No email is ever silently lost to a crash, restart, or
// transient Resend failure — every job ends sent, queued-retrying, or dead
// with its error preserved.
const db = require('./db');
const { encrypt, decrypt } = require('../encryption');
const { sendEmail, delightData, delightHtml } = require('../services/email');

const WORKER_INTERVAL_MS = Math.max(
  15000,
  Number(process.env.EMAIL_WORKER_INTERVAL_MS || 30000),
);
const LEASE_MS = 5 * 60 * 1000;
const BACKOFFS_MIN = [1, 10, 60, 360];
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const EMAIL_SUBJECT = 'Finish setting up Meowmin — your trial is ready';

async function enqueueEmailJob({ user_id, email, kind, tok, tok_hash, snapshot, display_name }) {
  const now = Date.now();
  let tok_enc = null;
  try {
    if (tok) tok_enc = encrypt(tok, user_id);
  } catch (_) {}
  const r = await db.execute({
    sql: `INSERT INTO email_jobs
          (user_id, email, kind, tok_hash, tok_enc, snapshot, display_name, status, attempts, next_retry_at, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', 0, ?, ?)`,
    args: [user_id, email, kind || 'mint', tok_hash || null, tok_enc, snapshot ? JSON.stringify(snapshot) : null, display_name || null, now, now],
  });
  return Number(r.lastInsertRowid);
}

async function attemptJob(job) {
  let snapshot;
  try {
    snapshot = job.snapshot ? JSON.parse(job.snapshot) : undefined;
  } catch (_) {
    snapshot = undefined;
  }
  // Raw token stays encrypted at rest; the CTA link needs it in clear.
  let tok = null;
  try {
    if (job.tok_enc) tok = decrypt(job.tok_enc, job.user_id);
  } catch (_) {}
  const d = await delightData(job.user_id, snapshot);
  const html = delightHtml({ name: job.display_name, email: job.email, tok, d });
  const r = await sendEmail({ to: job.email, subject: EMAIL_SUBJECT, html });
  return r;
}

function backoffFor(attempts) {
  if (attempts < BACKOFFS_MIN.length) return BACKOFFS_MIN[attempts] * 60 * 1000;
  return null; // dead after ~24h of retries
}

async function processEmailQueue() {
  const now = Date.now();
  try {
    // Reaper: sending rows whose lease expired (crash mid-send) go queued.
    await db.execute({
      sql: `UPDATE email_jobs SET status = 'queued', lease_expires_at = NULL
            WHERE status = 'sending' AND lease_expires_at IS NOT NULL AND lease_expires_at <= ?`,
      args: [now],
    });
  } catch (e) {
    console.error('[email-queue] reaper failed:', e.message);
  }

  let rows = [];
  try {
    const r = await db.execute({
      sql: `SELECT * FROM email_jobs
            WHERE status = 'queued' AND (next_retry_at IS NULL OR next_retry_at <= ?)
            ORDER BY created_at ASC LIMIT 5`,
      args: [now],
    });
    rows = r.rows;
  } catch (e) {
    console.error('[email-queue] claim failed:', e.message);
    return;
  }

  for (const job of rows) {
    if (now - Number(job.created_at || now) > MAX_AGE_MS) {
      await db.execute({
        sql: `UPDATE email_jobs SET status = 'dead', last_error = ? WHERE id = ?`,
        args: ['expired after 24h of retries', job.id],
      });
      continue;
    }
    await db.execute({
      sql: `UPDATE email_jobs SET status = 'sending', lease_expires_at = ?, attempts = COALESCE(attempts, 0) + 1 WHERE id = ?`,
      args: [now + LEASE_MS, job.id],
    });
    try {
      const r = await attemptJob(job);
      if (r.ok) {
        await db.execute({
          sql: `UPDATE email_jobs SET status = 'sent', sent_at = ?, resend_id = ?, last_error = NULL, lease_expires_at = NULL WHERE id = ?`,
          args: [Date.now(), r.id || null, job.id],
        });
      } else {
        throw new Error('send skipped (no API key)');
      }
    } catch (e) {
      const attempts = Number(job.attempts || 0) + 1;
      const delay = backoffFor(attempts);
      if (delay == null) {
        await db.execute({
          sql: `UPDATE email_jobs SET status = 'dead', last_error = ?, lease_expires_at = NULL WHERE id = ?`,
          args: [String(e.message).slice(0, 500), job.id],
        });
        console.error(`[email-queue] job ${job.id} dead:`, e.message);
      } else {
        await db.execute({
          sql: `UPDATE email_jobs SET status = 'queued', next_retry_at = ?, last_error = ?, lease_expires_at = NULL WHERE id = ?`,
          args: [Date.now() + delay, String(e.message).slice(0, 500), job.id],
        });
      }
    }
  }
}

// Fire-and-forget immediate attempt used at enqueue time so healthy sends
// still land in seconds; failures stay queued for the worker.
async function attemptNow(jobId) {
  try {
    const r = await db.execute({ sql: `SELECT * FROM email_jobs WHERE id = ?`, args: [jobId] });
    const job = r.rows[0];
    if (!job || job.status !== 'queued') return null;
    await db.execute({
      sql: `UPDATE email_jobs SET status = 'sending', lease_expires_at = ?, attempts = COALESCE(attempts, 0) + 1 WHERE id = ?`,
      args: [Date.now() + LEASE_MS, jobId],
    });
    const s = await attemptJob(job);
    if (s.ok) {
      await db.execute({
        sql: `UPDATE email_jobs SET status = 'sent', sent_at = ?, resend_id = ?, last_error = NULL, lease_expires_at = NULL WHERE id = ?`,
        args: [Date.now(), s.id || null, jobId],
      });
      return { ok: true, id: s.id || null };
    }
    await db.execute({
      sql: `UPDATE email_jobs SET status = 'queued', next_retry_at = ?, last_error = ?, lease_expires_at = NULL WHERE id = ?`,
      args: [Date.now() + BACKOFFS_MIN[0] * 60 * 1000, 'immediate attempt failed', jobId],
    });
    return { ok: false };
  } catch (e) {
    try {
      await db.execute({
        sql: `UPDATE email_jobs SET status = 'queued', next_retry_at = ?, last_error = ?, lease_expires_at = NULL WHERE id = ?`,
        args: [Date.now() + BACKOFFS_MIN[0] * 60 * 1000, String(e.message).slice(0, 500), jobId],
      });
    } catch (_) {}
    return { ok: false };
  }
}

async function latestJobStatus(user_id) {
  try {
    const r = await db.execute({
      sql: `SELECT status, created_at, sent_at FROM email_jobs WHERE user_id = ? ORDER BY created_at DESC LIMIT 1`,
      args: [user_id],
    });
    return r.rows[0] || null;
  } catch (_) {
    return null;
  }
}

async function autoSentToday(user_id) {
  try {
    const dayStart = Date.now() - 24 * 60 * 60 * 1000;
    const r = await db.execute({
      sql: `SELECT id FROM email_jobs WHERE user_id = ? AND kind = 'auto' AND status IN ('queued','sending','sent') AND created_at > ? LIMIT 1`,
      args: [user_id, dayStart],
    });
    return r.rows.length > 0;
  } catch (_) {
    return false;
  }
}

let workerTimer = null;
function startEmailWorker() {
  if (workerTimer) return;
  // First pass on boot so deploys drain anything left queued.
  processEmailQueue().catch((e) => console.error('[email-queue] boot pass failed:', e.message));
  workerTimer = setInterval(() => {
    processEmailQueue().catch((e) => console.error('[email-queue] pass failed:', e.message));
  }, WORKER_INTERVAL_MS);
}

module.exports = {
  enqueueEmailJob,
  attemptNow,
  processEmailQueue,
  startEmailWorker,
  latestJobStatus,
  autoSentToday,
  EMAIL_SUBJECT,
};
