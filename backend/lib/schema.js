const db = require('./db');
const { isWorker } = require('./runtime');

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
  ['shield_balance', 'INTEGER DEFAULT 0'],
];

const JOURNAL_CREATE_COLUMNS = ['id', 'user_id', 'content', 'created_at', 'ai_status', 'ai_attempts', 'ai_last_error', 'ai_next_retry_at', 'updated_at', 'content_hash'];
const JOURNAL_ALTER_COLUMNS = [
  ['ai_attempts', 'INTEGER DEFAULT 0'],
  ['ai_last_error', 'TEXT'],
  ['ai_next_retry_at', 'DATETIME'],
  ['updated_at', 'DATETIME'],
  ['content_hash', 'TEXT'],
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
      updated_at DATETIME,
      content_hash TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS insight_decks (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      journal_id TEXT NOT NULL,
      deck_date TEXT,
      status TEXT NOT NULL DEFAULT 'building',
      cards_json TEXT,
      served_at DATETIME,
      revealed_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE
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
     CREATE TABLE IF NOT EXISTS continue_tokens (
      tok_hash TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      rc_customer_id TEXT,
      snapshot TEXT,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      consumed_at INTEGER,
      resend_count INTEGER DEFAULT 0,
      last_sent_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS email_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      email TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'mint',
      tok_hash TEXT,
      tok_enc TEXT,
      snapshot TEXT,
      display_name TEXT,
      status TEXT NOT NULL DEFAULT 'queued',
      attempts INTEGER DEFAULT 0,
      next_retry_at INTEGER,
      lease_expires_at INTEGER,
      resend_id TEXT,
      last_error TEXT,
      created_at INTEGER NOT NULL,
      sent_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS external_offer_sessions (
      sid TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      rc_customer_id TEXT,
      external_transaction_token TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      consumed_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS google_external_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      external_transaction_id TEXT NOT NULL UNIQUE,
      paddle_event_id TEXT,
      paddle_transaction_id TEXT,
      paddle_subscription_id TEXT,
      user_id TEXT,
      kind TEXT NOT NULL,
      amount_micros INTEGER,
      currency TEXT,
      country_code TEXT,
      fee_micros INTEGER,
      status TEXT NOT NULL DEFAULT 'pending',
      google_error TEXT,
      reported_at INTEGER,
      created_at INTEGER NOT NULL
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS entitlement_transfer_tokens (
      token TEXT PRIMARY KEY,
      from_uid TEXT NOT NULL,
      product_id TEXT,
      expires_at_ms INTEGER,
      status TEXT NOT NULL DEFAULT 'pending',
      claimed_by_uid TEXT,
      created_at INTEGER NOT NULL,
      claimed_at INTEGER,
      FOREIGN KEY (from_uid) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
  `
    CREATE TABLE IF NOT EXISTS push_tokens (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      utc_offset INTEGER NOT NULL,
      reminders_enabled INTEGER NOT NULL DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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
  `
    CREATE TABLE IF NOT EXISTS family_groups (
      id TEXT PRIMARY KEY,
      owner_uid TEXT NOT NULL,
      max_members INTEGER NOT NULL DEFAULT 3,
      members TEXT NOT NULL DEFAULT '[]',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (owner_uid) REFERENCES users(id) ON DELETE CASCADE
    )
  `,
];

const PUSH_TOKEN_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_push_tokens_offset ON push_tokens(utc_offset)',
];

const ERROR_LOG_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_error_log_occurred_at ON error_log(occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_error_log_type ON error_log(type)',
];

const USER_TAG_MAP_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_user_tag_maps_user_tag ON user_tag_maps(user_id, tag)',
  'CREATE INDEX IF NOT EXISTS idx_user_task_tag_maps_user_tag ON user_task_tag_maps(user_id, tag)',
];

const DECK_INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_decks_user_status ON insight_decks(user_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_decks_user_date ON insight_decks(user_id, deck_date)',
  'CREATE INDEX IF NOT EXISTS idx_decks_journal ON insight_decks(journal_id, status)',
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
  await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_user_status ON journal_entries(user_id, ai_status)');
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

// Workers allow ~50 subrequests per invocation; the old initDB ran 40+
// sequential statements on EVERY cold boot, and this file's growth tipped it
// over the edge (prod-wide 1101s on deploy). initDB is now version-gated:
// steady-state boots cost a single probe subrequest, and deltas run chunked.
const SCHEMA_VERSION = '4';
// v4 = push_tokens table + indexes (FCM reminder tokens; previously only in
// migrate.js, so worker-boot initDB never converged on it).
// v3 = insight_decks table + deck indexes + journal_entries.updated_at/
// content_hash + journal_entries user_status index. Bump on future DDL and
// extend probeSchema/planMissingDdl accordingly.

// Max DDL statements applied per boot on Workers. Local/VPS runs are
// unchunked. Remainder is applied on subsequent boots (boot retries per
// request until the version marker sticks).
const BOOT_DDL_CHUNK = isWorker() ? 15 : 1000000;

function tableNameOf(stmt) {
  const m = String(typeof stmt === 'string' ? stmt : stmt.sql).match(
    /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)/i
  );
  return m ? m[1] : null;
}

function indexNameOf(stmt) {
  const m = String(typeof stmt === 'string' ? stmt : stmt.sql).match(
    /CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)/i
  );
  return m ? m[1] : null;
}

/**
 * Single-subrequest probe: schema marker, tables, tracked columns, indexes.
 * Throws on a fresh DB (no app_config) so callers take the full-ensure path.
 * pragma_table_info on a missing table yields zero rows (no error).
 */
async function probeSchema() {
  const probedTables = [
    'users',
    'journal_entries',
    'journal_ai',
    'user_tag_maps',
    'user_task_tag_maps',
  ];
  const colSelects = probedTables
    .map((t) => `SELECT 'col:${t}', name FROM pragma_table_info('${t}')`)
    .join(' UNION ALL ');
  const result = await db.execute(`
    SELECT 'version' AS kind, value AS name FROM app_config WHERE key = 'schema_version'
    UNION ALL SELECT 'table', name FROM sqlite_master WHERE type = 'table'
    UNION ALL SELECT 'index', name FROM sqlite_master WHERE type = 'index'
    UNION ALL SELECT 'fk:tag_index', "table" FROM pragma_foreign_key_list('tag_index')
    UNION ALL SELECT 'fk:task_tag_index', "table" FROM pragma_foreign_key_list('task_tag_index')
    UNION ALL ${colSelects}
  `);
  let version = null;
  const names = new Set();
  const columns = {};
  const indexes = new Set();
  const fks = {};
  for (const row of result.rows) {
    if (row.kind === 'version') {
      version = row.name;
    } else if (row.kind === 'table') {
      names.add(row.name);
    } else if (row.kind === 'index') {
      indexes.add(row.name);
    } else if (typeof row.kind === 'string' && row.kind.startsWith('fk:')) {
      const table = row.kind.slice(3);
      (fks[table] = fks[table] || []).push(row.name);
    } else if (typeof row.kind === 'string' && row.kind.startsWith('col:')) {
      const table = row.kind.slice(4);
      (columns[table] = columns[table] || []).push(row.name);
    }
  }
  return { version, names, columns, indexes, fks };
}

function syntheticState(probe) {
  return { names: probe.names, columns: probe.columns };
}

/**
 * Deterministic DDL delta from probe state. Every statement is idempotent
 * (IF NOT EXISTS / conditional ALTERs), so re-running after a partial boot
 * converges without extra bookkeeping.
 */
function planMissingDdl(probe) {
  const missing = [];
  for (const stmt of CREATE_STATEMENTS) {
    const table = tableNameOf(stmt);
    if (table && !probe.names.has(table)) missing.push(stmt);
  }
  for (const stmt of [...USER_TAG_MAP_INDEXES, ...DECK_INDEXES, ...ERROR_LOG_INDEXES, ...PUSH_TOKEN_INDEXES]) {
    const index = indexNameOf(stmt);
    if (index && !probe.indexes.has(index)) missing.push(stmt);
  }
  const state = syntheticState(probe);
  missing.push(
    ...missingColumnAlters(state, 'users', USER_CREATE_COLUMNS, USER_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'journal_entries', JOURNAL_CREATE_COLUMNS, JOURNAL_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'journal_ai', JOURNAL_AI_CREATE_COLUMNS, JOURNAL_AI_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'user_tag_maps', TAG_MAP_CREATE_COLUMNS, TAG_MAP_ALTER_COLUMNS),
    ...missingColumnAlters(state, 'user_task_tag_maps', TAG_MAP_CREATE_COLUMNS, TAG_MAP_ALTER_COLUMNS)
  );
  return missing;
}

async function runStatements(stmts) {
  // Statement-by-statement (NOT one db.batch): the libsql web client has
  // silently dropped trailing CREATEs from large batches before
  // (continue_tokens, external_offer_* needed manual backfill). Per-statement
  // executes make any failure loud instead of silent.
  for (const stmt of stmts) {
    try {
      await db.execute(stmt);
    } catch (e) {
      const preview = String(typeof stmt === 'string' ? stmt : stmt.sql).replace(/\s+/g, ' ').slice(0, 140);
      console.error('[DB] schema statement failed:', String(e.message).slice(0, 200), '|', preview);
      throw e;
    }
  }
}

async function markSchemaVersion() {
  await db.execute({
    sql: `INSERT INTO app_config (key, value) VALUES ('schema_version', ?)
          ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    args: [SCHEMA_VERSION],
  });
}

async function initDB() {
  console.log('[DB] Ensuring Turso schema...');

  let probe = null;
  try {
    probe = await probeSchema();
  } catch (_) {
    probe = null; // fresh DB (no app_config yet): full ensure below
  }

  if (probe && probe.version === SCHEMA_VERSION) {
    console.log(`[DB] Schema v${SCHEMA_VERSION} current, skipping.`);
  } else {
    const emptyProbe = {
      version: null,
      names: new Set(),
      columns: {},
      indexes: new Set(),
      fks: {},
    };
    const state = probe || emptyProbe;
    const missing = planMissingDdl(state);
    if (missing.length > BOOT_DDL_CHUNK) {
      // Fresh/very-stale DB on Workers: apply a slice now; the boot fails
      // this request but the NEXT request resumes (boot retries per request)
      // until the version marker sticks. Applied DDL is idempotent.
      console.warn(`[DB] applying schema slice ${BOOT_DDL_CHUNK}/${missing.length}, resuming next boot`);
      await runStatements(missing.slice(0, BOOT_DDL_CHUNK));
      throw new Error(`[DB] schema incomplete (${missing.length - BOOT_DDL_CHUNK} statements remain), retrying next boot`);
    }
    await runStatements(missing);

    if (state.names.has('journals')) {
      await db.execute(`
        INSERT OR IGNORE INTO journal_entries (id, user_id, content, created_at, ai_status)
        SELECT id, user_id, content, created_at, COALESCE(ai_status, 'pending')
        FROM journals
      `);
    }

    // Index tables + FK shape: only when something is actually missing, so
    // steady-state boots skip these extra subrequests entirely.
    const wantIndexes = [
      'idx_journal_entries_user',
      'idx_journal_entries_user_status',
      'idx_tag_index_user_tag',
      'idx_task_tag_index_user_tag',
    ];
    const needIndexTables =
      ['tag_index', 'task_tag_index'].some((t) => !state.names.has(t)) ||
      wantIndexes.some((i) => !state.indexes.has(i)) ||
      ['tag_index', 'task_tag_index'].some(
        (t) => state.names.has(t) && !(state.fks[t] || []).includes('journal_entries')
      );
    if (needIndexTables) {
      await ensureIndexTables(state.names);
    }
    try {
      await rebuildTagMapsFromIndexes();
    } catch (e) {
      // Tag maps are a best-effort backfill (similar-matches only). Never take
      // down boot for them: log loudly and continue so the API stays up.
      console.error('[DB] tag map rebuild failed (degraded similar-matches):', e.message);
    }
    await markSchemaVersion();
  }

  await seedAppConfig();
  await rebuildTagMapsFromIndexes().catch(() => {});
  await db.execute("UPDATE journal_entries SET ai_status = 'pending' WHERE ai_status = 'processing'");
  console.log('[DB] Schema ready.');
}

module.exports = { initDB, tableExists, hasColumn, probeSchema, SCHEMA_VERSION };
