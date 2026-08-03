const db = require('../lib/db');

const KEY_CACHE_TTL_MS = 60 * 60 * 1000;
const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

let cachedKeys = null;
let cachedKeysAt = 0;

async function fetchSigningKeys() {
  const now = Date.now();
  if (cachedKeys && now - cachedKeysAt < KEY_CACHE_TTL_MS) return cachedKeys;
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new Error(`JWKS fetch failed (${res.status})`);
  const body = await res.json();
  cachedKeys = Array.isArray(body.keys) ? body.keys : [];
  cachedKeysAt = Date.now();
  return cachedKeys;
}

function base64UrlDecode(input) {
  const b64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64.padEnd(Math.ceil(b64.length / 4) * 4, '=');
  return Buffer.from(padded, 'base64').toString('utf8');
}

function base64UrlToBytes(input) {
  const b64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64.padEnd(Math.ceil(b64.length / 4) * 4, '=');
  return Buffer.from(padded, 'base64');
}

async function verifyIdToken(idToken) {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) throw new Error('FIREBASE_PROJECT_ID is not configured');

  const parts = idToken.split('.');
  if (parts.length !== 3) throw new Error('Malformed ID token');

  let header;
  let payload;
  try {
    header = JSON.parse(base64UrlDecode(parts[0]));
    payload = JSON.parse(base64UrlDecode(parts[1]));
  } catch {
    throw new Error('Malformed ID token');
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp < nowSec) throw new Error('Token expired');
  if (payload.aud !== projectId) throw new Error('Invalid audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Invalid issuer');
  if (payload.iat && payload.iat > nowSec + 60) throw new Error('Token issued in future');
  if (payload.auth_time && payload.auth_time > nowSec + 300) throw new Error('auth_time in future');

  const keys = await fetchSigningKeys();
  const jwk = keys.find((k) => k.kid === header.kid && k.alg === 'RS256');
  if (!jwk) throw new Error('No matching signing key');

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const signature = base64UrlToBytes(parts[2]);
  const data = Buffer.from(`${parts[0]}.${parts[1]}`, 'utf8');
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', cryptoKey, signature, data);
  if (!valid) throw new Error('Invalid token signature');

  return { uid: payload.user_id || payload.sub, ...payload };
}

async function verifyAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  try {
    const decoded = await verifyIdToken(authHeader.slice('Bearer '.length).trim());
    req.uid = decoded.uid;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function compareVersions(a, b) {
  const pa = a.split('+')[0].split('.').map(Number);
  const pb = b.split('+')[0].split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const na = pa[i] || 0;
    const nb = pb[i] || 0;
    if (na > nb) return 1;
    if (na < nb) return -1;
  }
  return 0;
}

async function verifyAppVersion(req, res, next) {
  const versionHeader = req.headers['x-app-version'];
  if (versionHeader && req.uid) {
    db.execute({
      sql: 'UPDATE users SET app_version = ? WHERE id = ?',
      args: [String(versionHeader).trim(), req.uid],
    }).catch(() => {});
  }

  try {
    const cfg = await db.execute("SELECT key, value FROM app_config WHERE key IN ('minimum_app_version', 'update_url', 'update_message')");
    const config = {};
    for (const row of cfg.rows) config[row.key] = row.value;

    if (versionHeader && config.minimum_app_version) {
      const cmp = compareVersions(String(versionHeader).trim(), config.minimum_app_version);
      if (cmp < 0) {
        return res.status(426).json({
          error: 'upgrade_required',
          message: config.update_message || 'Please update your app to continue.',
          updateUrl: config.update_url || '',
          minimumVersion: config.minimum_app_version,
        });
      }
    }
  } catch (_) {}

  next();
}

module.exports = { verifyAuth, verifyAppVersion, compareVersions };
