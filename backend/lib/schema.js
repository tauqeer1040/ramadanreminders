const db = require('./db');

const USER_CREATE_COLUMNS = ['id', 'display_name', 'email', 'journal_count', 'relevant_tags', 'created_at', 'last_active'];
const USER_ALTER_COLUMNS = [
  ['stars', 'INTEGER DEFAULT 0'],
  ['claimed_bonuses', "TEXT DEFAULT '[]'"],
  ['purchases', "TEXT DEFAULT '[]'"],
  ['subscription_status', "TEXT DEFAULT 'none'"],
  ['subscription_product_id', 'TEXT'],
  ['subscription_expires_at', 'INTEGER'],
  ['subscription_trial_started_at', 'INTEGER'],
  ['app_version', 'TEXT'],
  ['grace_ms', 'INTEGER DEFAULT 1800000'],
  ['daily_award_date', 'TEXT'],
  ['daily_award_count', 'INTEGER DEFAULT 0'],
  ['ai_calls_date', 'TEXT'],
  ['ai_calls_count', 'INTEGER DEFAULT 0'],
  ['cat_name', 'TEXT'],
];

const JOURNAL_CREATE_COLUMNS = ['id', 'user_id', 'content', 'created_at', 'ai_status', 'ai_attempts', 'ai_last_error', 'ai_next_retry_at'];
const JOURNAL_ALTER_COLUMNS = [
  ['ai_attempts', 'INTEGER DEFAULT 0'],
  ['ai_last_error', 'TEXT'],
  ['ai_next_retry_at', 'DATETIME'],
];

const JOURNAL_AI_CREATE_COLUMNS = ['id', 'journal_id', 'user_id', 'summary', 'tags', 'quote', 'reference', 'suggested_tasks', 'task_tags', 'updated_at'];
const JOURNAL_AI_ALTER_COLUMNS = [
  ['suggested_tasks', "TEXT DEFAULT '[]'"],
  ['task_tags', "TEXT DEFAULT '[]'"],
];

const TAG_MAP_CREATE_COLUMNS = ['id', 'user_id', 'tag', 'journal_ids', 'journal_refs', 'updated_at'];
const TAG_MAP_ALTER_COLUMNS = [['journal_refs', "TEXT DEFAULT '[]'"]];

const CREATE_STATEMENTS = [
  `
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT,
      email TEXT,
      journal_count INTEGER DEFAULT 0,
      relevant_tags TEXT DEFAULT '[]',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_active DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS app_config (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  `,
  `
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
  `,
  `
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
  `,
  `
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
  `,
  `
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
  `,
  `
    CREATE TABLE IF NOT EXISTS webhook_events (
      event_id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      uid TEXT,
      processed_at INTEGER NOT NULL
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS error_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      occurred_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      type TEXT,
      message TEXT,
      stack TEXT,
      uid TEXT,
      route TEXT,
      method TEXT,
      request_body TEXT
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS streaks (
      uid TEXT PRIMARY KEY,
      streak INTEGER NOT NULL DEFAULT 1,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS friendships (
      user_a_uid TEXT NOT NULL,
      user_b_uid TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_a_uid, user_b_uid)
    )
  `,
];

const ERROR_LOG_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_error_log_occurred_at ON error_log(occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_error_log_type ON error_log(type)',
];

const USER_TAG_MAP_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_user_tag_maps_user_tag ON user_tag_maps(user_id, tag)',
  'CREATE INDEX IF NOT EXISTS idx_user_task_tag_maps_user_tag ON user_task_tag_maps(user_id, tag)',
];

async function tableExists(name) {
  const result = await db.execute({
    sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function getColumns(tableName) {
  if (!(await tableExists(tableName))) return [];
  const result = await db.execute(`PRAGMA table_info(${tableName})`);
  return result.rows.map((row) => row.name);
}

async function hasColumn(tableName, columnName) {
  const columns = await getColumns(tableName);
  return columns.includes(columnName);
}

async function getTablesAndColumns() {
  const tables = await db.execute("SELECT name FROM sqlite_master WHERE type = 'table'");
  const names = new Set(tables.rows.map((row) => row.name));
  const columns = {};
  for (const name of names) {
    const result = await db.execute(`PRAGMA table_info(${name})`);
    columns[name] = result.rows.map((row) => row.name);
  }
  return { names, columns };
}

function missingColumnAlters(state, tableName, createColumns, alterDefs) {
  const exists = state.columns[tableName] !== undefined;
  const present = new Set(exists ? state.columns[tableName] : createColumns);
  return alterDefs
    .filter(([name]) => !present.has(name))
    .map(([name, type]) => `ALTER TABLE ${tableName} ADD COLUMN ${name} ${type}`);
}

async function getForeignKeyTargets(tableName) {
  if (!(await tableExists(tableName))) return [];
  const result = await db.execute(`PRAGMA foreign_key_list(${tableName})`);
  return result.rows.map((row) => row.table);
}

async function recreateIndexTable(tableName) {
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
      INNER JOIN journal_entries AS journal_entries
        ON journal_entries.id = legacy.journal_id
    `);
    await db.execute(`DROP TABLE ${backupName}`);
  }
}

async function ensureIndexTables(names) {
  for (const tableName of ['tag_index', 'task_tag_index']) {
    let targets = [];
    if (names.has(tableName)) {
      const result = await db.execute(`PRAGMA foreign_key_list(${tableName})`);
      targets = result.rows.map((row) => row.table);
    }
    if (!names.has(tableName) || !targets.includes('journal_entries')) {
      await recreateIndexTable(tableName);
    }
  }

  await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_user ON journal_entries(user_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_index_user_tag ON tag_index(user_id, tag)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_task_tag_index_user_tag ON task_tag_index(user_id, tag)');
}

async function seedAppConfig() {
  const seed = [
    { key: 'latest_app_version', value: '1.0.0' },
    { key: 'minimum_app_version', value: '1.0.0' },
    { key: 'update_url', value: '' },
    { key: 'update_message', value: 'A new version of Meowmin is available. Please update to continue.' },
  ];
  await db.batch(
    seed.map((row) => ({
      sql: 'INSERT OR IGNORE INTO app_config (key, value) VALUES (?, ?)',
      args: [row.key, row.value],
    })),
    'write'
  );
}

async function rebuildTagMapsFromIndexes() {
  const count = await db.execute('SELECT COUNT(*) AS n FROM user_tag_maps');
  if (Number(count.rows[0]?.n || 0) > 0) return;

  const { upsertTagMapRow } = require('./tags');

  await db.execute('DELETE FROM user_tag_maps');
  await db.execute('DELETE FROM user_task_tag_maps');

  const reflectionRows = await db.execute(`
    SELECT i.user_id, i.tag, i.journal_id, j.created_at
    FROM tag_index i
    INNER JOIN journal_entries j ON j.id = i.journal_id
    ORDER BY i.user_id ASC, i.tag ASC, i.journal_id ASC
  `);
  for (const row of reflectionRows.rows) {
    await upsertTagMapRow('user_tag_maps', row.user_id, row.tag, row.journal_id, row.created_at);
  }

  const taskRows = await db.execute(`
    SELECT i.user_id, i.tag, i.journal_id, j.created_at
    FROM task_tag_index i
    INNER JOIN journal_entries j ON j.id = i.journal_id
    ORDER BY i.user_id ASC, i.tag ASC, i.journal_id ASC
  `);
  for (const row of taskRows.rows) {
    await upsertTagMapRow('user_task_tag_maps', row.user_id, row.tag, row.journal_id, row.created_at);
  }
}

async function initDB() {
  console.log('[DB] Ensuring Turso schema...');
  const state = await getTablesAndColumns();

  const alterations = [
    ...missingColumnAlters(state, 'users', USER_CREATE_COLUMNS, USER_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'journal_entries', JOURNAL_CREATE_COLUMNS, JOURNAL_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'journal_ai', JOURNAL_AI_CREATE_COLUMNS, JOURNAL_AI_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'user_tag_maps', TAG_MAP_CREATE_COLUMNS, TAG_MAP_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'user_task_tag_maps', TAG_MAP_CREATE_COLUMNS, TAG_MAP_ALTER_COLUMNS),
  ];

  await db.batch([...CREATE_STATEMENTS, ...USER_TAG_MAP_INDEXES, ...ERROR_LOG_INDEXES, ...alterations], 'write');

  if (state.names.has('journals')) {
    await db.execute(`
      INSERT OR IGNORE INTO journal_entries (id, user_id, content, created_at, ai_status)
      SELECT id, user_id, content, created_at, COALESCE(ai_status, 'pending')
      FROM journals
    `);
  }

  await ensureIndexTables(state.names);
  await seedAppConfig();
  await rebuildTagMapsFromIndexes();
  await db.execute("UPDATE journal_entries SET ai_status = 'pending' WHERE ai_status = 'processing'");
  console.log('[DB] Schema ready.');
}

module.exports = { initDB, tableExists, hasColumn };
