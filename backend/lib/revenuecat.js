/**
 * RevenueCat REST API v2 client (the only key type minted for new projects —
 * legacy v1 secret keys 403 with error 7723 "incompatible with API V1").
 *
 * Base: https://api.revenuecat.com/v2/projects/{project_id}/...
 * Auth: `Authorization: Bearer sk_...` (v2 keys; permissions enforced per key).
 *
 * Required key permissions (dashboard → API keys → edit the sk_ key):
 *   customer_information:customers:read         — entitlement checks
 *   customer_information:subscriptions:read     — plan product/expiry lookups
 *   customer_information:purchases:read         — one-time purchases (shield)
 *   customer_information:customers:read_write   — promotional entitlement grant
 *
 * Verified shapes (docs.api-v2/customer, 2026-09):
 *   GET  .../customers/{id}                    → { customer: { active_entitlements: { items: [{ entitlement_id, expires_at }] } } }
 *   GET  .../customers/{id}/subscriptions      → { items: [{ product_id, expires_at, auto_renewal_status, status }] }
 *   GET  .../customers/{id}/purchases          → { items: [{ product_id, purchase_token, expires_at? }] }
 *   POST .../customers/{id}/actions/grant_entitlement { entitlement_id, expires_at(ms) }
 */

const RC_BASE = 'https://api.revenuecat.com/v2';

function rcConfigured() {
  return Boolean(process.env.REVENUECAT_API_SECRET && process.env.REVENUECAT_PROJECT_ID);
}

/** Internal entitlement id (V2 has no display-name lookups on the customer
 *  endpoints). From BILLING_LIVE_SETUP.md; override via env if it changes. */
function entitlementId() {
  return process.env.REVENUECAT_ENTITLEMENT_ID || 'entl04c6421978';
}

function rcHeaders() {
  return { Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}` };
}

function rcUrl(pathAfterProject) {
  return `${RC_BASE}/projects/${encodeURIComponent(process.env.REVENUECAT_PROJECT_ID)}${pathAfterProject}`;
}

/** Thrown on auth/permission failures so callers can distinguish a key
 *  problem (fail-closed is safe; log loudly) from a store outage (fail-open). */
class RcAuthError extends Error {
  constructor(message) {
    super(message);
    this.name = 'RcAuthError';
  }
}

/**
 * Fetch a customer's active entitlements.
 * @returns {Promise<Array<{entitlement_id: string, expires_at: number|null}>>}
 */
async function rcActiveEntitlements(appUserId) {
  const res = await fetch(rcUrl(`/customers/${encodeURIComponent(appUserId)}`), {
    headers: rcHeaders(),
  });
  if (res.status === 401 || res.status === 403) {
    throw new RcAuthError(`RevenueCat auth failed (${res.status})`);
  }
  if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
  const body = await res.json();
  const list = body?.customer?.active_entitlements;
  const items = Array.isArray(list?.items) ? list.items : [];
  return items.map((e) => ({
    entitlement_id: e.entitlement_id,
    expires_at: e.expires_at ?? null,
  }));
}

/**
 * Fetch a customer's subscriptions (current state, includes expired ones).
 * @returns {Promise<Array<{product_id: string, expires_at: number|null, auto_renewal_status: string|null, status: string|null}>>}
 */
async function rcSubscriptions(appUserId) {
  const res = await fetch(rcUrl(`/customers/${encodeURIComponent(appUserId)}/subscriptions`), {
    headers: rcHeaders(),
  });
  if (res.status === 401 || res.status === 403) {
    throw new RcAuthError(`RevenueCat auth failed (${res.status})`);
  }
  if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
  const body = await res.json();
  const items = Array.isArray(body?.items) ? body.items : [];
  return items.map((s) => ({
    product_id: s.product_id,
    expires_at: s.expires_at ?? null,
    auto_renewal_status: s.auto_renewal_status ?? null,
    status: s.status ?? null,
  }));
}

/**
 * Fetch a customer's one-time (non-subscription) purchases.
 * @returns {Promise<Array<{product_id: string, purchase_token: string|null, expires_at: number|null}>>}
 */
async function rcPurchases(appUserId) {
  const res = await fetch(rcUrl(`/customers/${encodeURIComponent(appUserId)}/purchases`), {
    headers: rcHeaders(),
  });
  if (res.status === 401 || res.status === 403) {
    throw new RcAuthError(`RevenueCat auth failed (${res.status})`);
  }
  if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
  const body = await res.json();
  const items = Array.isArray(body?.items) ? body.items : [];
  return items.map((p) => ({
    product_id: p.product_id,
    purchase_token: p.purchase_token ?? null,
    expires_at: p.expires_at ?? null,
  }));
}

/**
 * Grant a promotional entitlement (transfer claim path).
 * @returns {Promise<boolean>} true when granted, false when blocked (409/other 4xx)
 */
async function rcGrantEntitlement(appUserId, entitlementId, expiresAtMs) {
  const res = await fetch(
    rcUrl(`/customers/${encodeURIComponent(appUserId)}/actions/grant_entitlement`),
    {
      method: 'POST',
      headers: { ...rcHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        entitlement_id: entitlementId,
        expires_at: expiresAtMs,
      }),
    },
  );
  if (res.status === 401 || res.status === 403) {
    throw new RcAuthError(`RevenueCat auth failed (${res.status})`);
  }
  return res.ok;
}

module.exports = {
  rcConfigured,
  entitlementId,
  rcActiveEntitlements,
  rcSubscriptions,
  rcPurchases,
  rcGrantEntitlement,
  RcAuthError,
};
