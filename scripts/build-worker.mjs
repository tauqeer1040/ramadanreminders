// Pre-bundles the backend into public/_worker.js with esbuild, producing a
// single self-contained ESM file that wrangler pages deploy uploads raw
// (no_bundle). This bypasses wrangler's pages bundler, whose unenv shim
// hardcodes compatibilityDate and replaces node:http with a throwing stub.
//
// Contract of the emitted file:
//   - single file, no relative imports (checkRawWorker rejects those)
//   - only node:* and cloudflare:* externals remain
//   - WORKER_RUNTIME is defined as '1' at build time, so backend/lib/client.js
//     drops the native @libsql/client branch (sqlite3 binding) via DCE
//   - a createRequire shim is injected first via banner: esbuild emits
//     __require("node:...") calls for builtin requires in CJS modules, and
//     workerd ESM workers have no global require — the shim makes them work.
import { build } from 'esbuild';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outfile = path.join(root, 'public', '_worker.js');

const NODE_BUILTINS = [
  'assert', 'async_hooks', 'buffer', 'child_process', 'cluster', 'console',
  'constants', 'crypto', 'dgram', 'diagnostics_channel', 'dns', 'domain',
  'events', 'fs', 'http', 'http2', 'https', 'inspector', 'module', 'net',
  'os', 'path', 'perf_hooks', 'process', 'punycode', 'querystring',
  'readline', 'repl', 'stream', 'string_decoder', 'sys', 'timers', 'tls',
  'trace_events', 'tty', 'url', 'util', 'v8', 'vm', 'wasi', 'worker_threads',
  'zlib',
];

// Rewrites bare builtin imports (require('crypto')) to node:-prefixed
// externals, which is the only form workerd accepts.
const nodeBuiltinsPlugin = {
  name: 'node-builtins',
  setup(build) {
    build.onResolve({ filter: /^[a-z][a-z0-9_]*$/ }, (args) => {
      if (NODE_BUILTINS.includes(args.path)) {
        return { path: `node:${args.path}`, external: true };
      }
    });
  },
};

mkdirSync(path.join(root, 'public'), { recursive: true });

await build({
  entryPoints: [path.join(root, 'worker', 'entry.js')],
  bundle: true,
  format: 'esm',
  platform: 'browser',
  target: 'es2022',
  outfile,
  external: ['node:*', 'cloudflare:*'],
  plugins: [nodeBuiltinsPlugin],
  banner: {
    js: "import { createRequire as __workerCreateRequire } from 'node:module'; const require = __workerCreateRequire(import.meta.url || 'file:///');",
  },
  define: {
    'process.env.WORKER_RUNTIME': '"1"',
  },
  logLevel: 'info',
  metafile: true,
}).then((result) => {
  const outputMeta = Object.values(result.metafile.outputs)[0];

  // Graph assertion: externals must only be node:* / cloudflare:* builtins.
  // checkRawWorker rejects relative imports in a raw _worker.js; esbuild
  // never emits those with bundle:true, but this guards against accidental
  // non-builtin externals slipping through the plugin/external lists.
  const externals = outputMeta.imports
    .filter((imp) => imp.external)
    .map((imp) => imp.path);
  const forbidden = externals.filter((p) => !p.startsWith('node:') && !p.startsWith('cloudflare:'));
  if (forbidden.length > 0) {
    throw new Error(`_worker.js has forbidden externals: ${forbidden.join(', ')}`);
  }

  // DCE assertion: the native @libsql/client (sqlite3 binding) branch of
  // backend/lib/client.js must have been eliminated by the WORKER_RUNTIME define.
  const bundledInputs = Object.keys(result.metafile.inputs);
  const nativeLibsql = bundledInputs.find((p) => /libsql[\\/]client[\\/]node\.js$/.test(p));
  if (nativeLibsql) {
    throw new Error(`native @libsql/client still bundled: ${nativeLibsql}`);
  }

  const sizeKb = (outputMeta.bytes / 1024).toFixed(1);
  console.log(`[worker] bundled -> public/_worker.js (${sizeKb} KB)`);
  console.log(`[worker] externals (${externals.length}): ${externals.sort().join(', ')}`);
  console.log('[worker] graph + DCE assertions passed.');
});
