// Assembles the Cloudflare Pages static output directory (public/) from the
// Flutter web build, the Astro landing site, and the backend shop assets.
//
//   - landing/dist            -> public/       (Astro site, includes /app copy)
//   - build/web               -> public/app    (fresh Flutter web output, overlays)
//   - backend/public/assets   -> public/assets (shop image assets)
//   - writes public/_headers and public/_redirects
//
// Each step is optional and warns when its source is missing, so the script
// can run before a full build. Run: npm run prepare:public
import { cpSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
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
copy(path.join(root, 'landing', 'dist'), publicDir);

// 2. Flutter web build -> public/app (authoritative, overrides landing copy).
copy(path.join(root, 'build', 'web'), path.join(publicDir, 'app'));

// 3. Shop assets -> public/assets
copy(path.join(root, 'backend', 'public', 'assets'), path.join(publicDir, 'assets'));

// 4. _redirects and _headers
writeFileSync(
  path.join(publicDir, '_redirects'),
  '# Flutter app hosted under /app\n/app  /app/index.html  200\n',
);

const headers = [
  '# Hashed Flutter assets are immutable; cache for a year.',
  '/app/build/*',
  '  Cache-Control: public, max-age=31536000, immutable',
  '/app/canvaskit/*',
  '  Cache-Control: public, max-age=31536000, immutable',
  '/app/assets/*',
  '  Cache-Control: public, max-age=31536000, immutable',
  '# Flutter entry point and service worker must always revalidate.',
  '/app/*',
  '  Cache-Control: public, max-age=0, must-revalidate',
  '',
].join('\n');
writeFileSync(path.join(publicDir, '_headers'), headers);

console.log('public/ assembled.');
