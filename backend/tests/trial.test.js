// Server-authoritative trial tests: one clock per uid, one per device.
// Run: npx jest tests/trial.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `trial-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'trial-test-secret-1234567890';

let db;
const handlers = {};
const fakeApp = {
  get: (p, fn) => { handlers[`GET ${p}`] = fn; },
  post: (p, fn) => { handlers[`POST ${p}`] = fn; },
};

function req(uid, body) {
  return { uid, body: body || {} };
}

function res() {
  const out = { code: 200, body: null };
  return {
    out,
    status(c) { out.code = c; return this; },
    json(o) { out.body = o; return this; },
  };
}

beforeAll(async () => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
  const { initDB } = require('../lib/schema');
  await initDB();
  db = require('../lib/db');
  require('../routes/trial')(fakeApp);
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

beforeEach(async () => {
  await db.execute('DELETE FROM users');
});

test('first start mints the clock; second start is idempotent', async () => {
  const r1 = res();
  await handlers['POST /api/v2/trial/start'](req('u1', { device_id: 'dev-A' }), r1);
  expect(r1.out.code).toBe(200);
  expect(r1.out.body.started).toBe(true);
  expect(r1.out.body.trialActive).toBe(true);

  const r2 = res();
  await handlers['POST /api/v2/trial/start'](req('u1', { device_id: 'dev-A' }), r2);
  expect(r2.out.body.started).toBe(true);
  expect(r2.out.body.trialStart).toBe(r1.out.body.trialStart);
});

test('reinstall + new login on same device is denied, no fresh clock', async () => {
  const r1 = res();
  await handlers['POST /api/v2/trial/start'](req('u1', { device_id: 'dev-B' }), r1);
  expect(r1.out.body.started).toBe(true);

  // Same device, different uid (reinstall + Google login).
  const r2 = res();
  await handlers['POST /api/v2/trial/start'](req('u2', { device_id: 'dev-B' }), r2);
  expect(r2.out.code).toBe(200);
  expect(r2.out.body.started).toBe(false);
  expect(r2.out.body.reason).toBe('device_claimed');
  expect(r2.out.body.trialActive).toBe(false);

  // No clock row minted for the second uid.
  const row = await db.execute({
    sql: 'SELECT subscription_trial_started_at FROM users WHERE id = ?',
    args: ['u2'],
  });
  expect(row.rows[0]?.subscription_trial_started_at).toBeFalsy();
});

test('trial-status reflects the device claim for the denied uid', async () => {
  const r1 = res();
  await handlers['POST /api/v2/trial/start'](req('u1', { device_id: 'dev-C' }), r1);
  const r2 = res();
  await handlers['POST /api/v2/trial/start'](req('u2', { device_id: 'dev-C' }), r2);

  const s = res();
  await handlers['GET /api/v2/trial-status'](req('u2'), s);
  expect(s.out.body.trialActive).toBe(false);
  expect(s.out.body.daysRemaining).toBe(0);
});

test('missing device_id is a 400', async () => {
  const r = res();
  await handlers['POST /api/v2/trial/start'](req('u9', {}), r);
  expect(r.out.code).toBe(400);
});
