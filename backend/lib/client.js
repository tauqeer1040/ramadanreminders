// Selects the libsql client build.
// - Worker runtime -> @libsql/client/web, a pure Web-API build (fetch/WebSocket).
//   The worker bundle defines WORKER_RUNTIME at build time, so esbuild drops
//   the native branch below (and its sqlite3 binding) entirely.
// - file: URLs (local dev) -> native @libsql/client (SQLite on disk)
// - libsql:// or https:// (Turso on VPS) -> @libsql/client/web
const url = process.env.TURSO_DATABASE_URL || 'file:local.db';

let mod;
if (process.env.WORKER_RUNTIME === '1') {
  mod = require('@libsql/client/web');
} else if (url.startsWith('file:')) {
  mod = require('@libsql/client');
} else {
  mod = require('@libsql/client/web');
}

module.exports = mod;
