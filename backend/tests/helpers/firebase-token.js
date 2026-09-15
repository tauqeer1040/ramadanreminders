// Test helper: mint real Firebase-style ID tokens and serve the matching JWKS.
//
// middleware/auth.js verifies ID tokens itself (Google JWKS + WebCrypto), so
// tests must exercise that path with a genuinely signed token rather than
// mocking firebase-admin, which the middleware no longer uses.
const crypto = require('crypto');

const PROJECT_ID = 'meowmin-34db1';
const KID = 'test-kid';

const b64url = (input) =>
  Buffer.from(input)
    .toString('base64')
    .replace(/=+$/, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

function makeKeypair() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const jwk = publicKey.export({ format: 'jwk' });
  return {
    privateKey,
    jwks: { keys: [{ ...jwk, kid: KID, alg: 'RS256', use: 'sig' }] },
  };
}

function signToken(privateKey, options = {}) {
  const {
    uid = 'user-abc',
    email = null,
    expiresInSec = 3600,
    issuedAgoSec = 0,
    projectId = PROJECT_ID,
  } = options;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', kid: KID, typ: 'JWT' }));
  const payload = b64url(
    JSON.stringify({
      user_id: uid,
      sub: uid,
      ...(email ? { email } : {}),
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      iat: now - issuedAgoSec,
      exp: now - issuedAgoSec + expiresInSec,
    }),
  );
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(`${header}.${payload}`)
    .sign(privateKey);
  return `${header}.${payload}.${b64url(signature)}`;
}

/** Routes the middleware's JWKS fetch to a local key set. Returns a restore fn. */
function stubJwks(jwks) {
  const realFetch = global.fetch;
  global.fetch = async (url, init) => {
    if (String(url).includes('securetoken')) {
      return { ok: true, json: async () => jwks };
    }
    return realFetch(url, init);
  };
  return () => {
    global.fetch = realFetch;
  };
}

/** Sets up project id + a keypair + signed-token helpers for one suite. */
function setupAuthTestEnv() {
  process.env.FIREBASE_PROJECT_ID = PROJECT_ID;
  const { privateKey, jwks } = makeKeypair();
  const restore = stubJwks(jwks);
  return {
    token: (options) => signToken(privateKey, options),
    restore,
  };
}

module.exports = {
  PROJECT_ID,
  setupAuthTestEnv,
  signToken,
  stubJwks,
  makeKeypair,
};
