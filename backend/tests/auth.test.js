const request = require('supertest');
const express = require('express');
const crypto = require('crypto');

const { setupAuthTestEnv, makeKeypair, signToken } = require('./helpers/firebase-token');

const { verifyAuth } = require('../middleware/auth');

function buildApp() {
  const app = express();
  app.use(express.json());
  app.get('/api/v2/protected', verifyAuth, (req, res) => {
    res.json({ uid: req.uid });
  });
  return app;
}

describe('auth middleware', () => {
  let auth;

  beforeAll(() => {
    // middleware/auth.js verifies ID tokens itself (Google JWKS + WebCrypto),
    // so the suite signs real tokens against a local key set.
    auth = setupAuthTestEnv();
  });

  afterAll(() => auth.restore());

  it('returns 401 when no Authorization header', async () => {
    const res = await request(buildApp()).get('/api/v2/protected');
    expect(res.status).toBe(401);
  });

  it('returns 401 when the header is not a Bearer token', async () => {
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', 'Basic abc123');
    expect(res.status).toBe(401);
  });

  it('returns 401 for a malformed token', async () => {
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', 'Bearer not-a-jwt');
    expect(res.status).toBe(401);
  });

  it('returns 401 when the signature does not match the JWKS', async () => {
    const other = makeKeypair();
    const forged = signToken(other.privateKey, { uid: 'attacker' });
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', `Bearer ${forged}`);
    expect(res.status).toBe(401);
    expect(res.body.uid).toBeUndefined();
  });

  it('returns 401 for an expired token', async () => {
    const expired = auth.token({ uid: 'user-abc', expiresInSec: -60 });
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', `Bearer ${expired}`);
    expect(res.status).toBe(401);
  });

  it('returns 401 for a token minted for another project', async () => {
    const foreign = auth.token({ uid: 'user-abc', projectId: 'other-project' });
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', `Bearer ${foreign}`);
    expect(res.status).toBe(401);
  });

  it('sets req.uid when the token is valid', async () => {
    const token = auth.token({ uid: 'user-abc' });
    const res = await request(buildApp())
      .get('/api/v2/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('user-abc');
  });

  it('exposes the token email claim for self-only endpoints', async () => {
    const token = auth.token({ uid: 'user-abc', email: 'a@b.example' });
    const app = express();
    app.get('/api/v2/whoami', verifyAuth, (req, res) => {
      res.json({ uid: req.uid, email: req.email });
    });
    const res = await request(app)
      .get('/api/v2/whoami')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.email).toBe('a@b.example');
  });
});
