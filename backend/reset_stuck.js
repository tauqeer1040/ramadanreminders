require('dotenv').config();
const { createClient } = require('@libsql/client');

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN
});

async function reset() {
  await db.execute("UPDATE journal_entries SET ai_status = 'pending' WHERE ai_status = 'processing'");
  console.log('Reset stuck items to pending');
  process.exit(0);
}

reset().catch(console.error);
