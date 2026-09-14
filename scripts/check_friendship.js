const fs = require('fs');
const path = require('path');

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const get = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const { createClient } = require(path.join(__dirname, '..', 'backend', 'node_modules', '@libsql', 'client'));
const db = createClient({ url: get('TURSO_DATABASE_URL'), authToken: get('TURSO_AUTH_TOKEN') });

const uid = process.argv[2] || '6BnaJGlRf7Q0U944OIEMSO2aACW2';

(async () => {
  const f = await db.execute({
    sql: `SELECT user_a_uid, user_b_uid FROM friendships
          WHERE user_a_uid = ? OR user_b_uid = ?`,
    args: [uid, uid],
  });
  console.log('friendships:', JSON.stringify(f.rows));

  const others = f.rows.map((r) => (r.user_a_uid === uid ? r.user_b_uid : r.user_a_uid));
  for (const o of others) {
    const s = await db.execute({
      sql: 'SELECT uid, streak, updated_at FROM streaks WHERE uid = ?',
      args: [o],
    });
    const u = await db.execute({
      sql: 'SELECT id, display_name, cat_name FROM users WHERE id = ?',
      args: [o],
    });
    console.log('friend', o, '->', JSON.stringify(s.rows[0] || null), JSON.stringify(u.rows[0] || null));
  }
})();
