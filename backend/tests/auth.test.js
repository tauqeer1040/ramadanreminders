const request = require('supertest');
const express = require('express');

// Mock firebase-admin before requiring auth middleware
jest.mock('firebase-admin', () => {
  const verifyIdToken = jest.fn();
  return {
    initializeApp: jest.fn(),
    credential: { cert: jest.fn() },
    auth: () => ({ verifyIdToken }),
    __verifyIdToken: verifyIdToken,
  };
});

const admin = require('firebase-admin');
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
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns 401 when no Authorization header', async () => {
    const app = buildApp();
    const res = await request(app).get('/api/v2/protected');
    expect(res.status).toBe(401);
  });

  it('returns 401 when token is invalid', async () => {
    admin.__verifyIdToken.mockRejectedValue(new Error('invalid token'));
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/protected')
      .set('Authorization', 'Bearer bad-token');
    expect(res.status).toBe(401);
  });

  it('sets req.uid when token is valid', async () => {
    admin.__verifyIdToken.mockResolvedValue({ uid: 'user-abc' });
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/protected')
      .set('Authorization', 'Bearer good-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('user-abc');
  });

  it('handles malformed Authorization header', async () => {
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/protected')
      .set('Authorization', 'NotBearer token');
    expect(res.status).toBe(401);
  });
});
