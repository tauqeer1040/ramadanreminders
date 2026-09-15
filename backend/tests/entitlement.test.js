// Server-authoritative entitlement tests: the verdict the client wall and the
// gated routes both trust.
// Run: npx jest tests/entitlement.test.js --forceExit
const path = require('path');
const os = require('os');
const fs = require('fs');

const DB_FILE = path.join(os.tmpdir(), `entitlement-test-${process.pid}.db`);
process.env.TURSO_DATABASE_URL = `file:${DB_FILE}`;
process.env.JOURNAL_ENCRYPTION_SECRET =
  process.env.JOURNAL_ENCRYPTION_SECRET || 'entitlement-test-secret-12345';
// No store credential: RC verification must fall back to "unavailable".
delete process.env.REVENUECAT_API_SECRET;

const DAY = 24 * 60 * 60 * 1000;
const TRIAL_MS = 3 * DAY;

let db;
let resolveEntitlement;
let requireEntitlement;
const handlers = {};
const fakeApp = {
  get: (p, fn) => { handlers[`GET ${p}`] = fn; },
  post: (p, fn) => { handlers[`POST ${p}`] = fn; },
};

function res() {
  const out = { code: 200, body: null };
  return {
    out,
    status(c) { out.code = c; return this; },
    json(o) { out.body = o; return this; },
  };
}

async function seedUser(id, fields) {
  const cols = ['id'];
  const args = [id];
  for (const [k, v] of Object.entries(fields || {})) {
    cols.push(k);
    args.push(v);
  }
  await db.execute({
    sql: `INSERT INTO users (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`,
    args,
  });
}

beforeAll(async () => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
  const { initDB } = require('../lib/schema');
  await initDB();
  db = require('../lib/db');
  ({ resolveEntitlement } = require('../lib/entitlement'));
  ({ requireEntitlement } = require('../middleware/entitlement'));
  require('../routes/entitlement')(fakeApp);
}, 60000);

afterAll(() => {
  try { fs.unlinkSync(DB_FILE); } catch (_) {}
});

beforeEach(async () => {
  await db.execute('DELETE FROM users');
  require('../lib/entitlement').clearRcCache();
});

test('unknown uid is allowed so onboarding can start a trial', async () => {
  const v = await resolveEntitlement('nobody');
  expect(v.active).toBe(true);
  expect(v.known).toBe(false);
});

test('active subscription is active', async () => {
  await seedUser('sub', {
    subscription_status: 'active',
    subscription_product_id: 'meowmin_yearly',
    subscription_expires_at: Date.now() + 5 * DAY,
  });
  const v = await resolveEntitlement('sub');
  expect(v.active).toBe(true);
  expect(v.reason).toBe('subscription');
});

test('lifetime subscription stays active without an expiry', async () => {
  await seedUser('life', {
    subscription_status: 'active',
    subscription_product_id: 'meowmin_lifetime',
  });
  const v = await resolveEntitlement('life');
  expect(v.active).toBe(true);
  expect(v.reason).toBe('subscription');
});

test('expired subscription with no expiry fallback is not active', async () => {
  await seedUser('lapsed', {
    subscription_status: 'expired',
    subscription_product_id: 'meowmin_monthly',
    subscription_expires_at: Date.now() - DAY,
    subscription_trial_started_at: Date.now() - 10 * DAY,
  });
  const v = await resolveEntitlement('lapsed');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('trial_expired');
});

test('a just-lapsed renewal keeps working (webhook lag grace)', async () => {
  await seedUser('renewing', {
    subscription_status: 'active',
    subscription_product_id: 'meowmin_monthly',
    // Expired 6 hours ago: the renewal webhook has not landed yet.
    subscription_expires_at: Date.now() - 6 * 60 * 60 * 1000,
  });
  const v = await resolveEntitlement('renewing');
  expect(v.active).toBe(true);
  expect(v.reason).toBe('subscription');
});

test('a long-dead active row is not treated as subscribed', async () => {
  await seedUser('dead-active', {
    subscription_status: 'active',
    subscription_product_id: 'meowmin_monthly',
    subscription_expires_at: Date.now() - 30 * DAY,
    subscription_trial_started_at: Date.now() - 40 * DAY,
  });
  const v = await resolveEntitlement('dead-active');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('trial_expired');
});

test('trial inside 3 days is active with days remaining', async () => {
  await seedUser('fresh', { subscription_trial_started_at: Date.now() - DAY });
  const v = await resolveEntitlement('fresh');
  expect(v.active).toBe(true);
  expect(v.reason).toBe('trial');
  expect(v.daysRemaining).toBeGreaterThanOrEqual(1);
});

test('trial past 3 days is denied when the store has nothing', async () => {
  await seedUser('over', {
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  const v = await resolveEntitlement('over');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('trial_expired');
});

test('a wiped device that burned its trial elsewhere is denied', async () => {
  await seedUser('owner', {
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
    trial_device_id: 'aid:dev-claimed',
  });
  await seedUser('fresh-login', { trial_device_id: 'aid:dev-claimed' });
  const v = await resolveEntitlement('fresh-login');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('device_claimed');
});

test('no trial on a young row is allowed (trial not started yet)', async () => {
  await seedUser('newbie', { created_at: new Date().toISOString().replace('T', ' ').split('.')[0] });
  const v = await resolveEntitlement('newbie');
  expect(v.active).toBe(true);
  expect(v.reason).toBe('no_trial');
});

test('no trial on a row older than a trial is denied (start bypass)', async () => {
  const old = new Date(Date.now() - 10 * DAY).toISOString().replace('T', ' ').split('.')[0];
  await seedUser('bypass', { created_at: old });
  const v = await resolveEntitlement('bypass');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('no_trial_stale');
});

test('store outage fails open so a payer is never locked out', async () => {
  await seedUser('payer', {
    subscription_status: 'none',
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  // Configured store credential + a failing lookup = our dependency is down,
  // so the verdict must fail open rather than lock a possible payer out.
  const realFetch = global.fetch;
  process.env.REVENUECAT_API_SECRET = 'test-secret';
  global.fetch = async () => { throw new Error('network down'); };
  try {
    const v = await resolveEntitlement('payer');
    expect(v.active).toBe(true);
    expect(v.reason).toBe('rc_unavailable');
  } finally {
    global.fetch = realFetch;
    delete process.env.REVENUECAT_API_SECRET;
    require('../lib/entitlement').clearRcCache();
  }
});

test('a live store entitlement unlocks a lapsed trial (expires_date shape)', async () => {
  await seedUser('store-active', {
    subscription_status: 'none',
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  const realFetch = global.fetch;
  process.env.REVENUECAT_API_SECRET = 'test-secret';
  // The subscriber API field is `expires_date` — reading `expires_at` (as the
  // code once did) made every real subscription look expired.
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      subscriber: {
        entitlements: {
          'Meowmin Max': {
            product_identifier: 'meowmin_yearly',
            expires_date: new Date(Date.now() + 60 * DAY).toISOString(),
          },
        },
      },
    }),
  });
  try {
    const v = await resolveEntitlement('store-active');
    expect(v.active).toBe(true);
    expect(v.reason).toBe('subscription');
  } finally {
    global.fetch = realFetch;
    delete process.env.REVENUECAT_API_SECRET;
    require('../lib/entitlement').clearRcCache();
  }
});

test('a store entitlement that expired does not unlock a lapsed trial', async () => {
  await seedUser('store-lapsed', {
    subscription_status: 'none',
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  const realFetch = global.fetch;
  process.env.REVENUECAT_API_SECRET = 'test-secret';
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      subscriber: {
        entitlements: {
          'Meowmin Max': {
            product_identifier: 'meowmin_yearly',
            expires_date: new Date(Date.now() - 2 * DAY).toISOString(),
          },
        },
      },
    }),
  });
  try {
    const v = await resolveEntitlement('store-lapsed');
    expect(v.active).toBe(false);
    expect(v.reason).toBe('trial_expired');
  } finally {
    global.fetch = realFetch;
    delete process.env.REVENUECAT_API_SECRET;
    require('../lib/entitlement').clearRcCache();
  }
});

test('an unconfigured store does not weaken the DB verdict', async () => {
  await seedUser('unconfigured', {
    subscription_status: 'none',
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  const v = await resolveEntitlement('unconfigured');
  expect(v.active).toBe(false);
  expect(v.reason).toBe('trial_expired');
});

test('gate: 402 on a denied verdict, next() when active', async () => {
  const gate = requireEntitlement();

  await seedUser('denied', {
    subscription_trial_started_at: Date.now() - TRIAL_MS - 60 * 1000,
  });
  const r = res();
  let passed = false;
  await gate({ uid: 'denied', path: '/api/v2/generate-insights' }, r, () => { passed = true; });
  expect(passed).toBe(false);
  expect(r.out.code).toBe(402);
  expect(r.out.body.reason).toBe('trial_expired');

  await seedUser('ok', { subscription_trial_started_at: Date.now() - DAY });
  const r2 = res();
  let passed2 = false;
  await gate({ uid: 'ok', path: '/api/v2/generate-insights' }, r2, () => { passed2 = true; });
  expect(passed2).toBe(true);
  expect(r2.out.code).toBe(200);
});

test('gate: unauthenticated request is 401', async () => {
  const gate = requireEntitlement();
  const r = res();
  await gate({ path: '/api/v2/generate-insights' }, r, () => { throw new Error('should not pass'); });
  expect(r.out.code).toBe(401);
});

test('route: GET /api/v2/entitlement returns the verdict', async () => {
  await seedUser('route-user', { subscription_trial_started_at: Date.now() - DAY });
  const r = res();
  await handlers['GET /api/v2/entitlement']({ uid: 'route-user' }, r);
  expect(r.out.code).toBe(200);
  expect(r.out.body.active).toBe(true);
  expect(r.out.body.reason).toBe('trial');
  expect(typeof r.out.body.serverNow).toBe('number');
});
