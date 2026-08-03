const request = require('supertest');
const express = require('express');
const crypto = require('crypto');

jest.mock('firebase-admin', () => {
  const verifyIdToken = jest.fn();
  return {
    initializeApp: jest.fn(),
    credential: { cert: jest.fn() },
    auth: () => ({ verifyIdToken }),
    __verifyIdToken: verifyIdToken,
  };
});

jest.mock('../lib/db', () => ({
  execute: jest.fn().mockResolvedValue({ rows: [] }),
}));

const db = require('../lib/db');

function buildApp() {
  const app = express();
  // capture raw body before json parse
  app.use(express.json({
    verify: (req, res, buf) => {
      if (req.url === '/api/v2/superwall-webhook') {
        req.rawBody = buf.toString();
      }
    },
  }));
  require('../routes/superwall')(app);
  return app;
}

function sign(payload, secret = 'test-secret') {
  const raw = JSON.stringify(payload);
  const sig = crypto.createHmac('sha256', secret).update(raw).digest('hex');
  return { raw, sig };
}

describe('superwall webhook', () => {
  beforeEach(() => {
    process.env.SUPERWALL_WEBHOOK_SECRET = 'test-secret';
    jest.clearAllMocks();
  });

  it('rejects request without signature', async () => {
    const app = buildApp();
    const { raw } = sign({ data: { id: 'evt_001' } });
    const res = await request(app)
      .post('/api/v2/superwall-webhook')
      .type('json')
      .send(raw);
    expect(res.status).toBe(401);
  });

  it('rejects request without event id', async () => {
    const app = buildApp();
    const { raw, sig } = sign({ type: 'test' });
    const res = await request(app)
      .post('/api/v2/superwall-webhook')
      .type('json')
      .set('x-signature', sig)
      .send(raw);
    expect(res.status).toBe(400);
  });

  it('rejects invalid signature', async () => {
    const app = buildApp();
    const { raw } = sign({ data: { id: 'evt_002' } });
    const res = await request(app)
      .post('/api/v2/superwall-webhook')
      .type('json')
      .set('x-signature', 'bad-sig')
      .send(raw);
    expect(res.status).toBe(401);
  });

  it('processes initial_purchase with valid signature', async () => {
    const payload = {
      type: 'initial_purchase',
      data: {
        id: 'evt_003',
        originalAppUserId: 'user-abc',
        productId: 'monthly_v1',
        periodType: 'TRIAL',
        expirationAt: Date.now() + 86400000 * 3,
      },
    };
    const { raw, sig } = sign(payload);
    const app = buildApp();
    const res = await request(app)
      .post('/api/v2/superwall-webhook')
      .type('json')
      .set('x-signature', sig)
      .send(raw);
    expect(res.status).toBe(200);
    expect(db.execute).toHaveBeenCalled();
  });

  it('fails closed on db error (returns 500)', async () => {
    db.execute.mockRejectedValue(new Error('db gone'));
    const payload = {
      type: 'initial_purchase',
      data: {
        id: 'evt_004',
        originalAppUserId: 'user-abc',
        productId: 'monthly_v1',
        periodType: 'TRIAL',
        expirationAt: Date.now() + 86400000,
      },
    };
    const { raw, sig } = sign(payload);
    const app = buildApp();
    const res = await request(app)
      .post('/api/v2/superwall-webhook')
      .type('json')
      .set('x-signature', sig)
      .send(raw);
    expect(res.status).toBe(500);
  });
});
