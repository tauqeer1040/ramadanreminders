// Restores a gzipped JSON dump (from backup-dump.mjs) into a Turso database.
// Usage: node scripts/restore-backup.mjs <dump.json.gz>
// Target DB comes from TURSO_DATABASE_URL / TURSO_AUTH_TOKEN.
// Run initDB() first so schema/indexes exist, then insert in FK-safe order.
import { createGunzip } from 'node:zlib';
import { createReadStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const require = createRequire(import.meta.url);
const requireB = createRequire(path.join(root, 'backend', 'package.json'));

const DATABASE_URL = process.env.TURSO_DATABASE_URL;
const AUTH_TOKEN = process.env.TURSO_AUTH_TOKEN;
const dumpPath = process.argv[2];

if (!DATABASE_URL || !AUTH_TOKEN) {
  console.error('Missing TURSO_DATABASE_URL or TURSO_AUTH_TOKEN');
  process.exit(1);
}
if (!dumpPath) {
  console.error('Usage: node scripts/restore-backup.mjs <dump.json.gz>');
  process.exit(1);
}

const { initDB } = require(path.join(root, 'backend', 'lib', 'schema.js'));

// FK-safe insertion order: parents before children.
const INSERT_ORDER = [
  'users',
  'journal_entries',
  'journal_ai',
  'user_tag_maps',
  'user_task_tag_maps',
  'webhook_events',
  'tag_index',
  'task_tag_index',
  'app_config',
];

async function main() {
  await initDB();

  let body = '';
  await pipeline(
    createReadStream(dumpPath),
    createGunzip(),
    async function* (source) {
      for await (const chunk of source) body += chunk;
    },
  );

  const { tables } = JSON.parse(body);
  console.log(`[restore] dump has tables: ${Object.keys(tables).join(', ')}`);

  const { createClient } = requireB('@libsql/client');
  const db = createClient({ url: DATABASE_URL, authToken: AUTH_TOKEN });

  const ordered = [
    ...INSERT_ORDER.filter((t) => tables[t]),
    ...Object.keys(tables).filter((t) => !INSERT_ORDER.includes(t)),
  ];

  for (const table of ordered) {
    const rows = tables[table];
    if (!rows.length) {
      console.log(`[restore] ${table}: 0 rows (skip)`);
      continue;
    }

    // Insert only columns that exist in BOTH the dump and the target table,
    // so restore survives schema drift (e.g. columns added after the dump).
    const info = await db.execute(`PRAGMA table_info(${table})`);
    const targetColumns = new Set(info.rows.map((r) => r.name));
    const columns = Object.keys(rows[0]).filter((c) => targetColumns.has(c));
    if (!columns.length) {
      console.log(`[restore] ${table}: no shared columns (skip)`);
      continue;
    }

    const placeholders = columns.map(() => '?').join(', ');
    const stmt = `INSERT OR REPLACE INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`;
    const values = rows.map((row) => columns.map((c) => row[c]));
    await db.batch(values.map((v) => ({ sql: stmt, args: v })));
    console.log(`[restore] ${table}: ${rows.length} rows`);
  }

  console.log('[restore] done.');
}

main().catch((err) => {
  console.error('[restore] FAILED:', err);
  process.exit(1);
});
