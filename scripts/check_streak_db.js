// Read-only check of the users row (streak sync verification). Never writes.
const fs = require('fs');
const path = require('path');

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const get = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const { createClient } = require(path.join(__dirname, '..', 'backend', 'node_modules', '@libsql', 'client'));
const db = createClient({
  url: get('TURSO_DATABASE_URL'),
  authToken: get('TURSO_AUTH_TOKEN'),
});

const uid = process.argv[2];
if (!uid) {
  console.error('usage: node scripts/check_streak_db.js <uid>');
  process.exit(1);
}

(async () => {
  // users.streak exists only after the v5 migration reaches production.
  try {
    const u = await db.execute({
      sql: 'SELECT id, streak, streak_date, stars, shield_balance FROM users WHERE id = ?',
      args: [uid],
    });
    if (u.rows.length) {
      console.log('users row:', JSON.stringify(u.rows[0], null, 2));
    } else {
      console.log('no users row for', uid);
    }
  } catch (e) {
    console.log('users.streak not available (pre-v5 prod schema):', e.message?.slice(0, 80));
  }

  const s = await db.execute({
    sql: 'SELECT streak, updated_at FROM streaks WHERE uid = ?',
    args: [uid],
  });
  console.log('legacy streaks row:', s.rows.length ? JSON.stringify(s.rows[0]) : '(none)');
})();
