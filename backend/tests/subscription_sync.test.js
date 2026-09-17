// Plan shield grants are one-time per plan. The client calls
// /subscription/sync on every cold start (RevenueCat identify), so a naive
// "status is active -> award" granted another allowance each launch.
// Run: npx jest tests/subscription_sync.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `subscription-sync-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'subscription-sync-test-secret-1';
// No store credential: the RevenueCat verification block is skipped.
delete process.env.REVENUECAT_API_SECRET;
delete process.env.REVENUECAT_PROJECT_ID;

let db;
const handlers = {};
const fakeApp = {
  get: (p, fn) => { handlers[`GET ${p}`] = fn; },
  post: (p, fn) => { handlers[`POST ${p}`] = fn; },
};

const DAY = 24 * 60 * 60 * 1000;

function res() {
  const out = { code: 200, body: null };
  return {
    out,
    status(c) { out.code = c; return this; },
    json(o) { out.body = o; return this; },
  };
}

function syncBody(productId, overrides = {}) {
  return {
    appUserId: 'u1',
    productId,
    status: 'active',
    expiresAt: Date.now() + 300 * DAY,
    periodType: 'normal',
    ...overrides,
  };
}

async function sync(body) {
  const r = res();
  await handlers['POST /api/v2/subscription/sync']({ uid: body.appUserId, body }, r);
  return r;
}

async function shieldsOf(uid) {
  const r = await db.execute({
    sql: 'SELECT shield_balance, plan_shields_product FROM users WHERE id = ?',
    args: [uid],
  });
  return r.rows[0] || {};
}

beforeAll(async () => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
  const { initDB } = require('../lib/schema');
  await initDB();
  db = require('../lib/db');
  require('../routes/subscription')(fakeApp);
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

beforeEach(async () => {
  await db.execute('DELETE FROM users');
});

test('a yearly plan grants its allowance on first sync', async () => {
  const r = await sync(syncBody('meowmin_yearly'));
  expect(r.out.code).toBe(200);
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance)).toBe(72);
  expect(row.plan_shields_product).toBe('meowmin_yearly');
});

test('repeated syncs (every app launch) do not stack more shields', async () => {
  await sync(syncBody('meowmin_yearly'));
  await sync(syncBody('meowmin_yearly'));
  await sync(syncBody('meowmin_yearly'));
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance)).toBe(72);
});

test('the 4-month plan grants its own allowance once', async () => {
  await sync(syncBody('meowmin_4month'));
  await sync(syncBody('meowmin_4month'));
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance)).toBe(18);
});

test('monthly plans grant no plan shields', async () => {
  await sync(syncBody('meowmin_monthly'));
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance ?? 0)).toBe(0);
});

test('moving to a bigger plan earns that plan\'s allowance', async () => {
  await sync(syncBody('meowmin_4month'));
  await sync(syncBody('meowmin_yearly'));
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance)).toBe(18 + 72);
  expect(row.plan_shields_product).toBe('meowmin_yearly');
});

test('a sync creates the user row when the account is new', async () => {
  await sync(syncBody('meowmin_yearly', { appUserId: 'brand-new' }));
  const row = await shieldsOf('brand-new');
  expect(Number(row.shield_balance)).toBe(72);
});

test('expired status grants nothing', async () => {
  await sync(syncBody('meowmin_yearly', { status: 'expired' }));
  const row = await shieldsOf('u1');
  expect(Number(row.shield_balance ?? 0)).toBe(0);
});

// ── RevenueCat as the source of truth (REST API v2) ───────────────────────

const RC_ENTITLEMENT_ID = 'entl04c6421978';

describe('with the store reachable', () => {
  const realFetch = global.fetch;

  // v2 stub: route by URL — customer (embedded active_entitlements),
  // subscriptions, purchases.
  function stubStore({ entitlements = [], subscriptions = [], purchases = [] } = {}) {
    process.env.REVENUECAT_API_SECRET = 'test-secret';
    process.env.REVENUECAT_PROJECT_ID = 'proj_test';
    global.fetch = async (url) => {
      const u = String(url);
      if (u.endsWith('/subscriptions')) {
        return { ok: true, json: async () => ({ items: subscriptions }) };
      }
      if (u.endsWith('/purchases')) {
        return { ok: true, json: async () => ({ items: purchases }) };
      }
      if (u.includes('/customers/')) {
        return {
          ok: true,
          json: async () => ({ customer: { active_entitlements: { items: entitlements } } }),
        };
      }
      throw new Error('unexpected RC url: ' + u);
    };
  }

  afterEach(() => {
    global.fetch = realFetch;
    delete process.env.REVENUECAT_API_SECRET;
    delete process.env.REVENUECAT_PROJECT_ID;
  });

  test('the store\'s plan is what gets recorded, not the claim', async () => {
    // Client claims the yearly plan; the store says 4-month.
    stubStore({
      entitlements: [{ entitlement_id: RC_ENTITLEMENT_ID, expires_at: Date.now() + 100 * DAY }],
      subscriptions: [{
        product_id: 'meowmin_4month',
        expires_at: Date.now() + 100 * DAY,
        auto_renewal_status: 'is_active',
      }],
    });
    const r = await sync(syncBody('meowmin_yearly'));
    expect(r.out.body.verified).toBe(true);
    expect(r.out.body.productId).toBe('meowmin_4month');

    const row = await db.execute({
      sql: 'SELECT subscription_product_id FROM users WHERE id = ?',
      args: ['u1'],
    });
    expect(row.rows[0].subscription_product_id).toBe('meowmin_4month');
    expect(Number((await shieldsOf('u1')).shield_balance)).toBe(18);
  });

  test('a claim the store does not confirm is ignored', async () => {
    stubStore({
      entitlements: [{ entitlement_id: RC_ENTITLEMENT_ID, expires_at: Date.now() - 5 * DAY }],
      subscriptions: [{
        product_id: 'meowmin_yearly',
        expires_at: Date.now() - 5 * DAY,
        auto_renewal_status: 'is_canceled',
      }],
    });
    const r = await sync(syncBody('meowmin_yearly'));
    expect(r.out.body.status).toBe('expired');

    const row = await db.execute({
      sql: 'SELECT subscription_status FROM users WHERE id = ?',
      args: ['u1'],
    });
    expect(row.rows[0].subscription_status).toBe('expired');
    expect(Number((await shieldsOf('u1')).shield_balance ?? 0)).toBe(0);
  });

  test('a store with no entitlement writes nothing', async () => {
    stubStore({});
    const r = await sync(syncBody('meowmin_yearly'));
    expect(r.out.body.verified).toBe(false);
    expect(r.out.body.reason).toBe('no_entitlement');
    const row = await shieldsOf('u1');
    expect(Number(row.shield_balance ?? 0)).toBe(0);
    expect(row.plan_shields_product ?? null).toBeNull();
  });

  test('an unreachable store writes nothing', async () => {
    process.env.REVENUECAT_API_SECRET = 'test-secret';
    process.env.REVENUECAT_PROJECT_ID = 'proj_test';
    global.fetch = async () => { throw new Error('network down'); };
    const r = await sync(syncBody('meowmin_yearly'));
    expect(r.out.body.verified).toBe(false);
    expect(r.out.body.reason).toBe('verify_failed');
    expect(Number((await shieldsOf('u1')).shield_balance ?? 0)).toBe(0);
  });
});
