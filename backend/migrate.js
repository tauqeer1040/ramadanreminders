require('dotenv').config();
const { createClient } = require('@libsql/client');

const db = createClient({
  url: process.env.TURSO_DATABASE_URL || 'file:local.db',
  authToken: process.env.TURSO_AUTH_TOKEN,
});

async function tableExists(name) {
  const result = await db.execute({
    sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function hasColumn(tableName, columnName) {
  if (!(await tableExists(tableName))) return false;
  const result = await db.execute(`PRAGMA table_info(${tableName})`);
  return result.rows.some((row) => row.name === columnName);
}

async function migrate() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT,
      email TEXT,
      fcm_token TEXT,
      journal_count INTEGER DEFAULT 0,
      relevant_tags TEXT DEFAULT '[]',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_active DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  if (!(await hasColumn('users', 'fcm_token'))) {
    await db.execute('ALTER TABLE users ADD COLUMN fcm_token TEXT');
  }

  await db.execute(`
    CREATE TABLE IF NOT EXISTS journal_entries (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      ai_status TEXT DEFAULT 'pending',
      ai_attempts INTEGER DEFAULT 0,
      ai_last_error TEXT,
      ai_next_retry_at DATETIME,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  if (!(await hasColumn('journal_entries', 'ai_attempts'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_attempts INTEGER DEFAULT 0');
  }
  if (!(await hasColumn('journal_entries', 'ai_last_error'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_last_error TEXT');
  }
  if (!(await hasColumn('journal_entries', 'ai_next_retry_at'))) {
    await db.execute('ALTER TABLE journal_entries ADD COLUMN ai_next_retry_at DATETIME');
  }

  if (await tableExists('journals')) {
    await db.execute(`
      INSERT OR IGNORE INTO journal_entries (id, user_id, content, created_at, ai_status)
      SELECT id, user_id, content, created_at, COALESCE(ai_status, 'pending')
      FROM journals
    `);
  }

  await db.execute(`
    CREATE TABLE IF NOT EXISTS journal_ai (
      id TEXT PRIMARY KEY,
      journal_id TEXT NOT NULL UNIQUE,
      user_id TEXT NOT NULL,
      summary TEXT,
      tags TEXT DEFAULT '[]',
      quote TEXT,
      reference TEXT,
      suggested_tasks TEXT DEFAULT '[]',
      task_tags TEXT DEFAULT '[]',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  if (!(await hasColumn('journal_ai', 'suggested_tasks'))) {
    await db.execute("ALTER TABLE journal_ai ADD COLUMN suggested_tasks TEXT DEFAULT '[]'");
  }
  if (!(await hasColumn('journal_ai', 'task_tags'))) {
    await db.execute("ALTER TABLE journal_ai ADD COLUMN task_tags TEXT DEFAULT '[]'");
  }

  for (const tableName of ['tag_index', 'task_tag_index']) {
    const backupName = `${tableName}_legacy`;
    if (await tableExists(backupName)) {
      await db.execute(`DROP TABLE ${backupName}`);
    }
    if (await tableExists(tableName)) {
      await db.execute(`ALTER TABLE ${tableName} RENAME TO ${backupName}`);
    }
    await db.execute(`
      CREATE TABLE ${tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        journal_id TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE,
        UNIQUE(user_id, tag, journal_id)
      )
    `);
    if (await tableExists(backupName)) {
      await db.execute(`
        INSERT OR IGNORE INTO ${tableName} (user_id, tag, journal_id)
        SELECT legacy.user_id, legacy.tag, legacy.journal_id
        FROM ${backupName} AS legacy
        INNER JOIN journal_entries ON journal_entries.id = legacy.journal_id
      `);
      await db.execute(`DROP TABLE ${backupName}`);
    }
  }

  await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_user ON journal_entries(user_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_index_user_tag ON tag_index(user_id, tag)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_task_tag_index_user_tag ON task_tag_index(user_id, tag)');
    await db.execute(`
      CREATE TABLE IF NOT EXISTS user_tag_maps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        journal_ids TEXT DEFAULT '[]',
        journal_refs TEXT DEFAULT '[]',
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(user_id, tag)
      )
    `);
    await db.execute(`
      CREATE TABLE IF NOT EXISTS user_task_tag_maps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        journal_ids TEXT DEFAULT '[]',
        journal_refs TEXT DEFAULT '[]',
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(user_id, tag)
      )
    `);
    await db.execute("ALTER TABLE user_tag_maps ADD COLUMN journal_refs TEXT DEFAULT '[]'").catch(() => {});
    await db.execute("ALTER TABLE user_task_tag_maps ADD COLUMN journal_refs TEXT DEFAULT '[]'").catch(() => {});
  await db.execute('CREATE INDEX IF NOT EXISTS idx_user_tag_maps_user_tag ON user_tag_maps(user_id, tag)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_user_task_tag_maps_user_tag ON user_task_tag_maps(user_id, tag)');

  console.log('Migration complete. Restart db2.js now.');
}

migrate()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
