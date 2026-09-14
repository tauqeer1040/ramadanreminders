const fs = require('fs');
const path = require('path');

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const get = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const { createClient } = require(path.join(__dirname, '..', 'backend', 'node_modules', '@libsql', 'client'));
const db = createClient({ url: get('TURSO_DATABASE_URL'), authToken: get('TURSO_AUTH_TOKEN') });

const uid = process.argv[2] || '6BnaJGlRf7Q0U944OIEMSO2aACW2';

(async () => {
  const r = await db.execute({
    sql: `SELECT DATE(created_at) AS day, COUNT(*) AS n
          FROM journal_entries WHERE user_id = ?
          GROUP BY day ORDER BY day DESC LIMIT 10`,
    args: [uid],
  });
  console.log('recent journal days:');
  for (const row of r.rows) console.log(' ', row.day, 'x' + Number(row.n));
})();
