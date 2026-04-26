require('dotenv').config();
const { createClient } = require('@libsql/client');

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN
});

async function check() {
  const tables = await db.execute("SELECT name FROM sqlite_master WHERE type='table';");
  console.log('Tables:', tables.rows.map(r => r.name));
  
  if (tables.rows.some(r => r.name === 'journals')) {
    const info = await db.execute("PRAGMA table_info(journals);");
    console.log('Journals schema:', info.rows);
  } else {
    console.log('Table journals NOT FOUND!');
  }
}

check().catch(console.error);
