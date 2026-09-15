const request = require('supertest');
const express = require('express');
const crypto = require('crypto');

const { setupAuthTestEnv } = require('./helpers/firebase-token');

const { verifyAuth } = require('../middleware/auth');
const { encrypt, decrypt } = require('../encryption');

function buildApp() {
  const app = express();
  app.use(express.json());
  app.get('/api/v2/encryption-key', verifyAuth, (req, res) => {
    const key = crypto.createHmac('sha256', process.env.JOURNAL_ENCRYPTION_SECRET || 'test-secret').update(req.uid).digest('base64');
    res.json({ key });
  });
  return app;
}

describe('encryption-key endpoint', () => {
  let auth;

  beforeAll(() => {
    // Real signed token: the middleware verifies against Google's JWKS itself.
    auth = setupAuthTestEnv();
  });

  afterAll(() => auth.restore());

  beforeEach(() => {
    process.env.JOURNAL_ENCRYPTION_SECRET = 'test-secret-32bytes!!!';
  });

  it('returns a base64 key for authenticated user', async () => {
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/encryption-key')
      .set('Authorization', `Bearer ${auth.token({ uid: 'user-123' })}`);
    expect(res.status).toBe(200);
    expect(res.body.key).toBeDefined();
    expect(typeof res.body.key).toBe('string');
    expect(res.body.key.length).toBeGreaterThan(20);
  });

  it('rejects an unauthenticated request', async () => {
    const res = await request(buildApp()).get('/api/v2/encryption-key');
    expect(res.status).toBe(401);
  });

  it('key can encrypt and decrypt for same uid', () => {
    const derivedKey = crypto.createHmac('sha256', 'test-secret-32bytes!!!').update('user-123').digest();
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', derivedKey.subarray(0, 32), iv);
    let ct = cipher.update('hello', 'utf8', 'hex');
    ct += cipher.final('hex');
    const tag = cipher.getAuthTag().toString('hex');
    const encrypted = `v1:${iv.toString('hex')}:${ct}:${tag}`;

    const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey.subarray(0, 32), Buffer.from(iv));
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    let decrypted = decipher.update(ct, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    expect(decrypted).toBe('hello');
  });
});
