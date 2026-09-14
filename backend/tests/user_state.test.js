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

test('streak merge: same-day report takes max and echoes back', async () => {
  const h = handlers['POST /api/v2/user/state'];
  const today = new Date().toISOString().slice(0, 10);

  let r = res();
  await h(req('u2', { streak: 4, streakDate: today }), r);
  expect(r.out.code).toBe(200);
  expect(r.out.body.streak).toBe(4);
  expect(r.out.body.streakDate).toBe(today);

  // Same-day lower report must not shrink it.
  r = res();
  await h(req('u2', { streak: 1, streakDate: today }), r);
  expect(r.out.body.streak).toBe(4);
});

test('streak merge: consecutive day advances, gap restarts, lagging device ignored', async () => {
  const h = handlers['POST /api/v2/user/state'];
  const fmt = (d) => d.toISOString().slice(0, 10);
  const today = new Date();
  const yesterday = new Date(today.getTime() - 86400000);

  // Consecutive-day higher report: takes the new value, date advances.
  let r = res();
  await h(req('u3', { streak: 2, streakDate: fmt(today) }), r);
  expect(r.out.body.streak).toBe(2);
  expect(r.out.body.streakDate).toBe(fmt(today));

  // Lagging device (yesterday's stale report) is ignored entirely.
  r = res();
  await h(req('u3', { streak: 9, streakDate: fmt(yesterday) }), r);
  expect(r.out.body.streak).toBe(2);
  expect(r.out.body.streakDate).toBe(fmt(today));

  // Gap > 1 day: a NEWER observation wins (streak broke while this device
  // was offline; the freshest report describes reality). An OLDER report is
  // already covered by the lagging-device case above.
  const future = new Date(today.getTime() + 3 * 86400000);
  r = res();
  await h(req('u3', { streak: 1, streakDate: fmt(future) }), r);
  expect(r.out.body.streak).toBe(1);
  expect(r.out.body.streakDate).toBe(fmt(future));
});

test('streak sync route writes users row (primary store)', async () => {
  require('../routes/invites')(fakeApp);
  const h = handlers['POST /api/v2/streaks/sync'];
  expect(h).toBeDefined();
  const today = new Date().toISOString().slice(0, 10);

  const r = res();
  await h(req('u4', { streak: 7 }), r);
  expect(r.out.code).toBe(200);
  expect(r.out.body.streak).toBe(7);

  // Verify it landed in users (read back through /user/state echo path).
  const r2 = res();
  await handlers['POST /api/v2/user/state'](req('u4', { streak: 1, streakDate: today }), r2);
  expect(r2.out.body.streak).toBe(7); // same-day max keeps 7
});
