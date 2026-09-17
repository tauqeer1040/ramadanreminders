/**
 * Upload build/app/outputs/bundle/release/app-release.aab to the Play
 * production track (full rollout) via the Play Developer API.
 *
 * Used because fastlane isn't installed on this machine; mirrors the
 * android/fastlane Fastfile `prod` lane (same service-account JSON).
 *
 * Usage:  cd backend && node ../scripts/upload-play.mjs [track]
 *         track defaults to "production"; bump pubspec versionCode first —
 *         Play rejects a reused versionCode.
 */
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const requireB = createRequire(path.join(ROOT, 'backend', 'package.json'));
const { GoogleAuth } = requireB('google-auth-library');

const KEY_FILE = path.join(ROOT, 'android', 'fastlane', 'play-developer-api.json');
const AAB = path.join(ROOT, 'build', 'app', 'outputs', 'bundle', 'release', 'app-release.aab');
const PACKAGE = 'com.taucity.meowmin';
const TRACK = process.argv[2] || 'production';
const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}`;

for (const f of [KEY_FILE, AAB]) {
  if (!fs.existsSync(f)) {
    console.error(`Missing file: ${f}`);
    process.exit(1);
  }
}

const auth = new GoogleAuth({
  keyFile: KEY_FILE,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});
const client = await auth.getClient();

async function api(method, url, body, headers = {}) {
  try {
    const res = await client.request({ url, method, data: body, headers, timeout: 300000 });
    return res.data;
  } catch (e) {
    const detail = e.response?.data ?? e.message;
    const err = new Error(`API ${method} ${url.replace(BASE, '')} failed: ${JSON.stringify(detail)}`);
    err.status = e.response?.status;
    err.body = detail;
    throw err;
  }
}

const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

// 1) Open an edit (also validates the service account + permissions).
const edit = await api('POST', `${BASE}/edits`, {});
log(`Edit opened: ${edit.id}`);

// 2) Show current track state.
const before = await api('GET', `${BASE}/edits/${edit.id}/tracks/${TRACK}`);
const cur = before.releases?.[0];
log(`Current ${TRACK} release: ${cur?.name ?? '(none)'} status=${cur?.status ?? '-'} versionCodes=${JSON.stringify(cur?.versionCodes ?? [])}`);

// 3) Upload the AAB. Large bundles may return a long-running Operation;
//    in that case fall back to polling the edit's bundle list. If the
//    versionCode was already committed by a previous run, reuse it.
log('Uploading AAB (77MB, this can take a while)...');
let versionCode;
try {
  const up = await api(
    'POST',
    `${BASE}/edits/${edit.id}/bundles?uploadType=media`,
    fs.readFileSync(AAB),
    { 'Content-Type': 'application/octet-stream' },
  );
  if (up.versionCode) {
    versionCode = up.versionCode;
    log(`Bundle uploaded: versionCode=${versionCode}`);
  } else if (up.name || up.done === false) {
    log(`Upload accepted as operation (${up.name}); polling for processing...`);
    versionCode = await pollBundles(edit.id);
    log(`Bundle processed: versionCode=${versionCode}`);
  } else {
    throw new Error('Unexpected upload response: ' + JSON.stringify(up));
  }
} catch (e) {
  const used = /already been used|Version code/i.test(String(e.body ? JSON.stringify(e.body) : e.message));
  if (!used) throw e;
  log('versionCode already committed previously — reusing existing bundle');
  versionCode = await pollBundles(edit.id, true);
}

async function pollBundles(editId, requireExisting = false) {
  const started = Date.now();
  for (;;) {
    const bundles = await api('GET', `${BASE}/edits/${editId}/bundles`);
    const vcs = (bundles.bundles ?? []).map((b) => b.versionCode);
    const latest = Math.max(...vcs, 0);
    if (latest > 0) return latest;
    if (requireExisting) throw new Error('No existing bundles found in edit');
    if (Date.now() - started > 5 * 60 * 1000) throw new Error('bundle processing timed out');
    await new Promise((r) => setTimeout(r, 10 * 1000));
  }
}

// 4) Point the track at the new bundle with a full rollout ("completed").
await api('POST', `${BASE}/edits/${edit.id}/tracks/${TRACK}`, {
  releases: [{ versionCodes: [String(versionCode)], status: 'completed' }],
});
log(`${TRACK} track set: versionCode=${versionCode} status=completed (full rollout)`);

// 5) Commit the edit — this pushes it live into the Play pipeline.
await api('POST', `${BASE}/edits/${edit.id}:commit`, {});
log(`Committed. versionCode ${versionCode} is now rolling out to production.`);
