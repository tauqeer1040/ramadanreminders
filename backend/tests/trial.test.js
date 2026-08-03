const request = require('supertest');
const express = require('express');
const { verifyAuth } = require('../middleware/auth');

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

// Mock cache to avoid cross-test pollution
jest.mock('../lib/cache', () => ({
  getCache: jest.fn().mockReturnValue(null),
  setCache: jest.fn(),
  clearUserCache: jest.fn(),
  clearJournalCache: jest.fn(),
}));

jest.mock('../lib/db', () => ({
  execute: jest.fn().mockResolvedValue({ rows: [] }),
}));

const db = require('../lib/db');

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/v2', (req, res, next) => verifyAuth(req, res, next));
  require('../routes/trial')(app);
  return app;
}

describe('GET /api/v2/trial-status', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    admin.__verifyIdToken.mockResolvedValue({ uid: 'user-abc' });
  });

  it('returns default trial for new user', async () => {
    db.execute.mockResolvedValue({ rows: [] });
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/trial-status')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(200);
    expect(res.body.trialActive).toBe(true);
    expect(res.body.daysRemaining).toBe(3);
  });

  it('returns trial expired when past 3 days', async () => {
    const threeDaysAgo = Date.now() - 4 * 86400000;
    db.execute.mockResolvedValue({
      rows: [{
        subscription_status: 'none',
        subscription_trial_started_at: threeDaysAgo,
        subscription_expires_at: null,
        grace_ms: 1800000,
      }],
    });
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/trial-status')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(200);
    expect(res.body.trialActive).toBe(false);
    expect(res.body.daysRemaining).toBe(0);
  });

  it('returns active for paying subscriber', async () => {
    const future = Date.now() + 86400000 * 30;
    db.execute.mockResolvedValue({
      rows: [{
        subscription_status: 'active',
        subscription_trial_started_at: null,
        subscription_expires_at: future,
        grace_ms: 1800000,
      }],
    });
    const app = buildApp();
    const res = await request(app)
      .get('/api/v2/trial-status')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(200);
    expect(res.body.trialActive).toBe(true);
    expect(res.body.graceMs).toBe(1800000);
    expect(res.body.subscriptionStatus).toBe('active');
  });

  it('requires auth', async () => {
    const app = buildApp();
    const res = await request(app).get('/api/v2/trial-status');
    expect(res.status).toBe(401);
  });
});
