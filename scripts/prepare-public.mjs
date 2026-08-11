// Assembles the Cloudflare Pages static output directory (public/) from the
// Flutter web build, the Astro landing site, and the backend shop assets.
//
//   - sites/meowmin/dist      -> public/       (Astro site, includes /app copy)
//   - build/web               -> public/app    (fresh Flutter web output, overlays)
//   - backend/public/assets   -> public/assets (shop image assets)
//   - writes public/_headers and public/_redirects
//
// Each step is optional and warns when its source is missing, so the script
// can run before a full build. Run: npm run prepare:public
import { cpSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const publicDir = path.join(root, 'public');

function pathExists(p) {
  try {
    return statSync(p).isDirectory() || statSync(p).isFile();
  } catch {
    return false;
  }
}

function copy(src, dest) {
  if (!pathExists(src)) {
    console.warn(`[warn] source missing, skipping: ${path.relative(root, src)}`);
    return;
  }
  mkdirSync(dest, { recursive: true });
  cpSync(src, dest, { recursive: true });
  console.log(`[ok] ${path.relative(root, src)} -> ${path.relative(root, dest)}`);
}

// 1. Landing site (Astro). Overlays public/, so run first.
copy(path.join(root, 'sites', 'meowmin', 'dist'), publicDir);

// 2. Flutter web build -> public/app (authoritative, overrides landing copy).
copy(path.join(root, 'build', 'web'), path.join(publicDir, 'app'));

// 2a. Remove canvaskit/ — Flutter loads it from gstatic CDN (buildConfig lacks
//     useLocalCanvasKit), so the local 37 MB folder is never served.
const canvaskitDir = path.join(publicDir, 'app', 'canvaskit');
if (pathExists(canvaskitDir)) {
  rmSync(canvaskitDir, { recursive: true, force: true });
  console.log('[ok] removed unused canvaskit/ from public/app');
}

// 2b. Fix base href — Flutter always resets it to "/" but we serve from /app/
const indexHtml = path.join(publicDir, 'app', 'index.html');
try {
  let html = readFileSync(indexHtml, 'utf8');
  if (html.includes('<base href="/">')) {
    html = html.replace('<base href="/">', '<base href="/app/">');
    writeFileSync(indexHtml, html);
    console.log('[ok] patched base href -> /app/');
  }
} catch {
  // index.html missing — nothing to patch
}

// 3. Shop assets -> public/assets
copy(path.join(root, 'backend', 'public', 'assets'), path.join(publicDir, 'assets'));

// 4. _redirects and _headers
// /app without trailing slash → redirect to /app/
// /app/* → serve as-is (no redirect, so Flutter assets load correctly)
writeFileSync(
  path.join(publicDir, '_redirects'),
  [
    '# Flutter app hosted under /app',
    '/app  /app/  301',
  ].join('\n'),
);

const headers = [
  '# HTML files must never be cached to avoid stale base href issues',
  '/app/index.html',
  '  Cache-Control: no-store, no-cache, must-revalidate',
  '  Pragma: no-cache',
  '',
  '# Hashed Flutter assets are immutable; cache for a year.',
  '/app/build/*',
  '  Cache-Control: public, max-age=31536000, immutable',
  '/app/assets/*',
  '  Cache-Control: public, max-age=31536000, immutable',
  '# Flutter entry point and service worker must always revalidate.',
  '# Explicit Content-Type fixes stale CDN cache serving JS as text/html.',
  '# Surrogate-Control tells CF edge to never cache these responses.',
  '/app/*.js',
  '  Cache-Control: no-cache, must-revalidate',
  '  Surrogate-Control: no-store',
  '  Content-Type: application/javascript',
  '/app/*.json',
  '  Cache-Control: no-cache, must-revalidate',
  '  Surrogate-Control: no-store',
  '  Content-Type: application/json',
  '/app/*.wasm',
  '  Cache-Control: no-cache, must-revalidate',
  '  Surrogate-Control: no-store',
  '  Content-Type: application/wasm',
  '',
].join('\n');
writeFileSync(path.join(publicDir, '_headers'), headers);

console.log('public/ assembled.');
