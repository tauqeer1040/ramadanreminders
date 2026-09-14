const fs = require('fs');
const path = require('path');

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const get = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const { createClient } = require(path.join(__dirname, '..', 'backend', 'node_modules', '@libsql', 'client'));
const db = createClient({ url: get('TURSO_DATABASE_URL'), authToken: get('TURSO_AUTH_TOKEN') });

(async () => {
  const cols = await db.execute('PRAGMA table_info(users)');
  console.log('users columns:', cols.rows.map((r) => r.name).join(', '));
  const v = await db.execute("SELECT value FROM app_config WHERE key = 'schema_version'");
  console.log('schema_version:', v.rows[0]?.value ?? '(unset)');
})();
