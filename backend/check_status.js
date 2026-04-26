require('dotenv').config();
const { createClient } = require('@libsql/client');

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN
});

async function check() {
  const result = await db.execute("SELECT id, ai_status FROM journal_entries ORDER BY created_at DESC LIMIT 5");
  console.table(result.rows);
  process.exit(0);
}

check().catch(console.error);
