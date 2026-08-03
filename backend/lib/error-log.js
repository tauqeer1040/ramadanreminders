// Minimal self-hosted error capture: writes errors into the error_log table.
// Deliberately fire-and-forget: never throws, never blocks the caller, so it
// is safe to call from error handlers and the AI poller.
const db = require('./db');

const RETENTION_DAYS = 30;

async function logError({ type, message, stack, uid, route, method, body }) {
  try {
    await db.execute({
      sql: `
        INSERT INTO error_log (type, message, stack, uid, route, method, request_body)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        String(type || 'error').slice(0, 100),
        String(message || '').slice(0, 1000),
        String(stack || '').slice(0, 8000),
        uid ? String(uid).slice(0, 255) : null,
        route ? String(route).slice(0, 255) : null,
        method ? String(method).slice(0, 20) : null,
        body ? JSON.stringify(body).slice(0, 4000) : null,
      ],
    });
    await db.execute({
      sql: "DELETE FROM error_log WHERE occurred_at < DATETIME('now', ?)",
      args: [`-${RETENTION_DAYS} days`],
    });
  } catch (e) {
    console.error('[error-log] failed to record error:', e.message);
  }
}

async function listErrors(limit = 50) {
  const result = await db.execute({
    sql: `
      SELECT occurred_at, type, message, uid, route, method
      FROM error_log
      ORDER BY id DESC
      LIMIT ?
    `,
    args: [Math.min(Math.max(Number(limit) || 50, 1), 500)],
  });
  return result.rows;
}

module.exports = { logError, listErrors };
