// Merge-only device backup: max/union, never overwrite-down.
// Run: npx jest tests/user_state.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `user-state-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'user-state-test-secret-1234567890';

const handlers = {};
const fakeApp = {
  get: (p, fn) => { handlers[`GET ${p}`] = fn; },
  post: (p, fn) => { handlers[`POST ${p}`] = fn; },
};

function req(uid, body) {
  return { uid, body: body || {}, params: {} };
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
  require('../routes/users')(fakeApp);
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

test('POST /user/state merges up (max stars/shields, union purchases)', async () => {
  const h = handlers['POST /api/v2/user/state'];
  expect(h).toBeDefined();

  let r = res();
  await h(req('u1', { stars: 100, purchases: ['shop_13'], shieldBalance: 2 }), r);
  expect(r.out.code).toBe(200);
  expect(r.out.body.success).toBe(true);
  expect(Number(r.out.body.stars)).toBe(100);

  // Lower device values must NOT shrink the server row.
  r = res();
  await h(req('u1', { stars: 10, purchases: ['shop_14'], shieldBalance: 0 }), r);
  expect(r.out.code).toBe(200);
  expect(Number(r.out.body.stars)).toBe(100);
  expect(Number(r.out.body.shield_balance)).toBe(2);
  expect(JSON.parse(r.out.body.purchases).sort()).toEqual(['shop_13', 'shop_14']);

  // Higher values merge up.
  r = res();
  await h(req('u1', { stars: 250, shieldBalance: 5 }), r);
  expect(Number(r.out.body.stars)).toBe(250);
  expect(Number(r.out.body.shield_balance)).toBe(5);
});

test('POST /user/state rejects invalid payloads', async () => {
  const h = handlers['POST /api/v2/user/state'];
  const r = res();
  await h(req('u1', { stars: -5 }), r);
  expect(r.out.code).toBe(400);
});
