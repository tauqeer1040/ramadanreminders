require('dotenv').config();
const { createClient } = require('@libsql/client');

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN
});

async function verify() {
  const result = await db.execute("SELECT * FROM journal_ai LIMIT 3");
  console.log('--- ALL Journal AI Rows ---');
  for (const row of result.rows) {
    console.log(`\nID: ${row.journal_id}`);
    console.log(`Tasks: ${row.suggested_tasks}`);
  }
  process.exit(0);
}

verify().catch(console.error);
