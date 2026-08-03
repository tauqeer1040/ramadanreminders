// Dumps every table in the Turso database to a single gzipped JSON file.
// Usage: node scripts/backup-dump.mjs [outfile]
//   outfile defaults to backup/meowmin-<YYYYMMDD-HHmmss>.json.gz
// Enumerates tables from sqlite_master so future schema additions are
// included automatically. Run from the repo root.
import { createGzip } from 'node:zlib';
import { createWriteStream, mkdirSync, statSync } from 'node:fs';
import { Readable } from 'node:stream';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pipeline } from 'node:stream/promises';
import { createRequire } from 'node:module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

const requireB = createRequire(path.join(root, 'backend', 'package.json'));

const DATABASE_URL = process.env.TURSO_DATABASE_URL;
const AUTH_TOKEN = process.env.TURSO_AUTH_TOKEN;

if (!DATABASE_URL || !AUTH_TOKEN) {
  console.error('Missing TURSO_DATABASE_URL or TURSO_AUTH_TOKEN');
  process.exit(1);
}

const { createClient } = requireB('@libsql/client');
const db = createClient({ url: DATABASE_URL, authToken: AUTH_TOKEN });

async function dump() {
  const tables = await db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
  const data = { dumped_at: new Date().toISOString(), tables: {} };

  for (const { name } of tables.rows) {
    const rows = await db.execute(`SELECT * FROM ${name}`);
    data.tables[name] = rows.rows;
    console.log(`[dump] ${name}: ${rows.rows.length} rows`);
  }
  return data;
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

const outfile = process.argv[2] || path.join(root, 'backup', `meowmin-${timestamp()}.json.gz`);
mkdirSync(path.dirname(outfile), { recursive: true });

const data = await dump();
const json = JSON.stringify(data, null, 2);
console.log(`[dump] total ${(json.length / 1024).toFixed(1)} KB raw`);

await pipeline(
  Readable.from([Buffer.from(json)]),
  createGzip(),
  createWriteStream(outfile),
);
const sizeKb = (statSync(outfile).size / 1024).toFixed(1);
console.log(`[dump] wrote ${outfile} (${sizeKb} KB)`);
