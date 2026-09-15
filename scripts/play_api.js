// Read-only Google Play Developer API probe.
//
// Signs a JWT with the fastlane service-account key, exchanges it for an
// access token, then inspects the app: one-time products (the Streak Shield
// consumable), in-app products and the release tracks (to find the live
// versionCode before uploading a new bundle).
//
// Usage: node scripts/play_api.js [products|tracks|all]
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const KEY_PATH = path.join(__dirname, '..', 'android', 'fastlane', 'play-developer-api.json');
const PACKAGE = 'com.taucity.meowmin';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}`;

function b64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

async function accessToken() {
  const sa = JSON.parse(fs.readFileSync(KEY_PATH, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: SCOPE,
      aud: sa.token_uri,
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(signingInput)
    .sign(sa.private_key);
  const jwt = `${signingInput}.${b64url(signature)}`;

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`token error ${res.status}: ${JSON.stringify(body)}`);
  return body.access_token;
}

async function get(token, url) {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch (_) {
    body = text;
  }
  return { status: res.status, body };
}

async function products(token) {
  console.log('--- one-time products (new monetization model) ---');
  const one = await get(token, `${BASE}/oneTimeProducts`);
  console.log(one.status, JSON.stringify(one.body, null, 2).slice(0, 2500));

  console.log('--- in-app products (legacy v3) ---');
  const legacy = await get(token, `${BASE}/inappproducts`);
  console.log(legacy.status, JSON.stringify(legacy.body, null, 2).slice(0, 2500));
}

async function tracks(token) {
  // edits.insert is a POST (a GET hits Google's 404 page).
  const insert = await fetch(`${BASE}/edits`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });
  const inserted = await insert.json().catch(() => ({}));
  if (insert.status !== 200) {
    console.log('edits insert failed', insert.status, JSON.stringify(inserted).slice(0, 400));
    return;
  }
  const editId = inserted.id;
  try {
    const t = await get(token, `${BASE}/edits/${editId}/tracks`);
    if (t.status !== 200) {
      console.log('tracks read failed', t.status, JSON.stringify(t.body).slice(0, 500));
      return;
    }
    for (const track of t.body.tracks || []) {
      const releases = (track.releases || []).map((r) => ({
        status: r.status,
        versionCodes: r.versionCodes,
        name: r.name,
      }));
      console.log(`track ${track.track}:`, JSON.stringify(releases));
    }
  } finally {
    await fetch(`${BASE}/edits/${editId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    }).catch(() => {});
  }
}

(async () => {
  const what = process.argv[2] || 'all';
  const token = await accessToken();
  console.log('access token acquired');
  if (what === 'products' || what === 'all') await products(token);
  if (what === 'tracks' || what === 'all') await tracks(token);
})().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
