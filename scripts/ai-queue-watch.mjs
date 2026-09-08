// Watchdog for the goal "AI insights for every journal".
// Fails (non-zero exit) when journals sit without insights past grace, so the
// scheduled workflow goes red and notifies. Reads Turso directly — works even
// when the API worker itself is down.
//
// Thresholds: any journal pending past 45 min grace, or any deck building for
// 2h+, or any journal_ai-less failure newer than 24h is a breach.
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const requireB = createRequire(path.join(__dirname, '..', 'backend', 'package.json'));

const DATABASE_URL = process.env.TURSO_DATABASE_URL;
const AUTH_TOKEN = process.env.TURSO_AUTH_TOKEN;
if (!DATABASE_URL || !AUTH_TOKEN) {
  console.error('Missing TURSO_DATABASE_URL or TURSO_AUTH_TOKEN');
  process.exit(2);
}

const { createClient } = requireB('@libsql/client');
const db = createClient({ url: DATABASE_URL, authToken: AUTH_TOKEN });

const breached = [];

async function check(label, sql, args, explain) {
  const r = await db.execute({ sql, args });
  const n = Number(r.rows[0]?.n || 0);
  const oldest = r.rows[0]?.oldest_min == null ? null : Number(r.rows[0].oldest_min);
  console.log(`${n > 0 ? 'BREACH' : 'ok'}: ${label} n=${n}${oldest == null ? '' : ` oldest=${oldest}min`}`);
  if (n > 0) breached.push(`${label}: ${explain} (n=${n})`);
}

await check(
  'pending-past-grace',
  `SELECT COUNT(*) AS n,
     MAX(CAST((strftime('%s','now') - strftime('%s', COALESCE(ai_next_retry_at, created_at))) / 60 AS INTEGER)) AS oldest_min
   FROM journal_entries
   WHERE ai_status = 'pending'
     AND (ai_next_retry_at IS NULL OR ai_next_retry_at <= DATETIME('now', '-45 minutes'))`,
  [],
  'journals waiting for insights past 45min grace'
);

await check(
  'stuck-building',
  `SELECT COUNT(*) AS n,
     MAX(CAST((strftime('%s','now') - strftime('%s', created_at)) / 60 AS INTEGER)) AS oldest_min
   FROM insight_decks WHERE status = 'building' AND created_at < DATETIME('now', '-2 hours')`,
  [],
  'decks building for 2h+ (AI worker not completing)'
);

await check(
  'recent-failures',
  `SELECT COUNT(*) AS n,
     MAX(CAST((strftime('%s','now') - strftime('%s', created_at)) / 60 AS INTEGER)) AS oldest_min
   FROM journal_entries
   WHERE ai_status = 'failed' AND created_at > DATETIME('now', '-24 hours')`,
  [],
  'journals failed in the last 24h (check error_log ai_poll_journal)'
);

const done = await db.execute({
  sql: `SELECT COUNT(*) AS n FROM journal_ai WHERE updated_at > DATETIME('now', '-24 hours')`,
});
const made = await db.execute({
  sql: `SELECT COUNT(*) AS n FROM journal_entries WHERE created_at > DATETIME('now', '-24 hours')`,
});
console.log(`info: journals24h=${made.rows[0]?.n ?? 0} completed24h=${done.rows[0]?.n ?? 0}`);

if (breached.length > 0) {
  console.error(`\nAI-QUEUE BREACH:\n- ${breached.join('\n- ')}`);
  process.exit(1);
}
console.log('\nAI queue healthy.');
