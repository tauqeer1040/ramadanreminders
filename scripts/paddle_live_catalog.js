#!/usr/bin/env node
// Creates live Paddle catalog mirroring sandbox inventory.
// Usage: PADDLE_API_KEY=pdl_live_apikey_... node scripts/paddle_live_catalog.js [--dry-run]
// Requires: npm i @paddle/paddle-node-sdk (or uses fetch fallback)

const DRY = process.argv.includes('--dry-run');
const API_KEY = process.env.PADDLE_API_KEY;
if (!API_KEY && !DRY) {
  console.error('Set PADDLE_API_KEY=pdl_live_apikey_... (live, not sandbox)');
  process.exit(1);
}
if (API_KEY && API_KEY.includes('sdbx')) {
  console.error('Sandbox key detected (pdl_sdbx_). Use live key for this script.');
  process.exit(1);
}

// Mirror of sandbox: Meowmin (standard/lifetime) + Tier B (saas)
const CATALOG = [
  {
    name: 'Meowmin',
    tax_category: 'standard',
    description: 'Meowmin subscriptions',
    prices: [
      { name: '3-day-trial', description: 'monthly', amount: '1900', currency: 'USD', interval: 'month', frequency: 1, trial: { interval: 'day', frequency: 3, amount: '100' } },
      { name: 'yearly', description: 'yearly-trial', amount: '9900', currency: 'USD', interval: 'year', frequency: 1, trial: { interval: 'day', frequency: 3, amount: '100' } },
      { name: 'Lifetime ', description: 'Lifetime', amount: '19900', currency: 'USD', interval: null },
    ],
  },
  {
    name: 'Meowmin Tier B',
    tax_category: 'saas',
    description: 'Tier B',
    prices: [
      { name: 'Monthly', description: 'Tier B monthly subscription', amount: '1500', currency: 'USD', interval: 'month', frequency: 1, trial: { interval: 'day', frequency: 30, amount: '100' } },
      { name: 'Yearly', description: 'Tier B yearly subscription', amount: '9900', currency: 'USD', interval: 'year', frequency: 1, trial: { interval: 'day', frequency: 30, amount: '100' } },
    ],
  },
];

async function paddleFetch(path, opts = {}) {
  const res = await fetch(`https://api.paddle.com${path}`, {
    ...opts,
    headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json', ...(opts.headers || {}) },
  });
  const body = await res.text();
  let json; try { json = JSON.parse(body); } catch { json = body; }
  if (!res.ok) throw new Error(`${res.status} ${path}: ${JSON.stringify(json).slice(0, 2000)}`);
  return json;
}

async function run() {
  if (DRY) {
    console.log('[dry-run] Would create:', JSON.stringify(CATALOG, null, 2));
    console.log('\nSet PADDLE_API_KEY live and re-run without --dry-run.');
    return;
  }
  for (const prod of CATALOG) {
    console.log(`Creating product: ${prod.name} (${prod.tax_category})`);
    const pRes = await paddleFetch('/products', {
      method: 'POST',
      body: JSON.stringify({ name: prod.name, tax_category: prod.tax_category, description: prod.description }),
    });
    const product = pRes.data || pRes;
    const productId = product.id;
    console.log(`  -> ${productId}`);
    for (const pr of prod.prices) {
      const billing_cycle = pr.interval ? { interval: pr.interval, frequency: pr.frequency } : null;
      const trial_period = pr.trial ? { interval: pr.trial.interval, frequency: pr.trial.frequency, unit_price: { amount: pr.trial.amount, currency_code: pr.currency } } : null;
      const body = {
        product_id: productId,
        name: pr.name,
        description: pr.description,
        unit_price: { amount: pr.amount, currency_code: pr.currency },
        ...(billing_cycle ? { billing_cycle } : {}),
        ...(trial_period ? { trial_period } : {}),
      };
      console.log(`  Price: ${pr.name} ${pr.amount} ${pr.currency}/${pr.interval || 'one-time'}`);
      const priceRes = await paddleFetch('/prices', { method: 'POST', body: JSON.stringify(body) });
      const price = priceRes.data || priceRes;
      console.log(`    -> ${price.id}`);
    }
  }
  console.log('\nDone. Copy pro_ / pri_ IDs into RevenueCat (live Paddle app) and attach to entitlement Meowmin Max.');
  console.log('Docs: docs/BILLING_LIVE_SETUP.md');
}

run().catch((e) => { console.error(e); process.exit(1); });
