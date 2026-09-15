const db = require('./db');

/**
 * Server-authoritative entitlement.
 *
 * The client gate is advisory: a wiped install, a rolled-back clock or a
 * repackaged APK can all claim an active trial. This module is the verdict
 * the backend enforces on expensive routes, so a stolen/bypassed client can
 * still be cut off.
 *
 * Rules (in order):
 *  1. No row at all            -> active ("no_trial"): brand-new user must be
 *                                 able to onboard and start a trial.
 *  2. Active subscription      -> active ("subscription").
 *  3. Trial inside 3 days      -> active ("trial").
 *  4. Otherwise verify against RevenueCat. A live entitlement means active
 *     ("subscription", source "revenuecat") — this is what keeps paying
 *     users unlocked when the DB row lags the store. An RC *error* fails
 *     open (never block a possible payer on an API outage), while a definite
 *     "no entitlement" denies.
 *  5. Trial started and over   -> inactive ("trial_expired").
 *  6. No trial on record but the device was burned on another uid
 *                              -> inactive ("device_claimed").
 *  7. No trial on record and the row is older than a trial would be
 *                              -> inactive ("no_trial_stale"). Guards the
 *                                 "never call /trial/start" bypass.
 */

const TRIAL_DAYS = 3;
const TRIAL_MS = TRIAL_DAYS * 24 * 60 * 60 * 1000;
const RC_ENTITLEMENT_ID = 'Meowmin Max';
const RC_CACHE_TTL_MS = 60 * 1000;

const rcCache = new Map();

/** SQLite `CURRENT_TIMESTAMP` is UTC `YYYY-MM-DD HH:MM:SS` (no zone marker). */
function parseSqliteDate(value) {
  if (value == null) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  const s = String(value).trim();
  if (!s) return null;
  const iso = s.includes('T') ? s : s.replace(' ', 'T');
  const zoned = /[zZ]$|[+-]\d{2}:?\d{2}$/.test(iso) ? iso : `${iso}Z`;
  const ms = Date.parse(zoned);
  return Number.isFinite(ms) ? ms : null;
}

// A paid row whose expiry has just passed is still treated as active: Paddle
// and RevenueCat webhooks can lag a renewal by hours, and locking a renewing
// subscriber out of the app for that window would be far worse than granting
// a stale row a few extra days.
const SUBSCRIPTION_LAG_GRACE_MS = 3 * 24 * 60 * 60 * 1000;

function hasActiveSubscription(row, now) {
  const status = row?.subscription_status;
  if (status !== 'active' && status !== 'trial') return false;
  const product = String(row?.subscription_product_id || '').toLowerCase();
  if (product.includes('lifetime')) return true;
  const expiresAt =
    row?.subscription_expires_at == null
      ? null
      : Number(row.subscription_expires_at);
  if (expiresAt == null) return true;
  return expiresAt > now - SUBSCRIPTION_LAG_GRACE_MS;
}

/**
 * Live RevenueCat check. Returns `{ ok, active }` so callers can tell a
 * definite "no entitlement" (ok:true, active:false) from a lookup failure
 * (ok:false) that must fail open.
 */
async function rcEntitlementActive(uid) {
  // Not configured is NOT the same as unavailable: with no store credential
  // there is nothing to verify against, so the DB verdict stands instead of
  // failing open (which would make the whole gate a no-op).
  if (!process.env.REVENUECAT_API_SECRET) {
    return { ok: false, configured: false, active: false };
  }
  const hit = rcCache.get(uid);
  if (hit && Date.now() - hit.at < RC_CACHE_TTL_MS) {
    return { ok: true, active: hit.active };
  }
  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      { headers: { Authorization: `Bearer ${process.env.REVENUECAT_API_SECRET}` } },
    );
    if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
    const body = await res.json();
    const ent = body?.subscriber?.entitlements?.[RC_ENTITLEMENT_ID];
    let active = false;
    if (ent) {
      if (ent.unlimited) {
        active = true;
      } else if (ent.expires_date) {
        const exp = new Date(ent.expires_date).getTime();
        active = Number.isFinite(exp) && Date.now() < exp;
      } else {
        active = false;
      }
    }
    rcCache.set(uid, { at: Date.now(), active });
    return { ok: true, active };
  } catch (e) {
    console.warn('[Entitlement] RC check failed (fail-open):', e.message);
    return { ok: false, configured: true, active: false };
  }
}

async function deviceClaimedElsewhere(uid, deviceId) {
  if (!deviceId) return false;
  try {
    const r = await db.execute({
      sql: `SELECT 1 FROM users
            WHERE trial_device_id = ? AND subscription_trial_started_at IS NOT NULL
              AND id != ? LIMIT 1`,
      args: [deviceId, uid],
    });
    return r.rows.length > 0;
  } catch (_) {
    return false;
  }
}

/**
 * @returns {Promise<{
 *   active: boolean, reason: string, known: boolean, verified: boolean,
 *   trialStart: number|null, expiresAt: number|null,
 *   daysRemaining: number, serverNow: number, trialDays: number
 * }>}
 */
async function resolveEntitlement(uid, { verifyRc = true } = {}) {
  const now = Date.now();
  const base = {
    serverNow: now,
    trialDays: TRIAL_DAYS,
    trialStart: null,
    expiresAt: null,
    known: true,
    verified: false,
    daysRemaining: 0,
  };

  let row = null;
  try {
    const r = await db.execute({
      sql: `SELECT subscription_status, subscription_product_id, subscription_expires_at,
                   subscription_trial_started_at, trial_device_id, created_at
            FROM users WHERE id = ?`,
      args: [uid],
    });
    row = r.rows[0] || null;
  } catch (e) {
    console.error('[Entitlement] DB read failed (fail-open):', e.message);
    return { ...base, active: true, known: false, reason: 'db_error' };
  }

  if (!row) {
    // Never-granted user: onboarding still needs to run. A trial start is
    // recorded by /trial/start before any gated route matters.
    return { ...base, active: true, known: false, reason: 'no_trial', daysRemaining: TRIAL_DAYS };
  }

  const expiresAt =
    row.subscription_expires_at == null ? null : Number(row.subscription_expires_at);

  if (hasActiveSubscription(row, now)) {
    return {
      ...base,
      active: true,
      reason: 'subscription',
      expiresAt,
      trialStart:
        row.subscription_trial_started_at == null
          ? null
          : Number(row.subscription_trial_started_at),
      daysRemaining:
        expiresAt == null
          ? TRIAL_DAYS
          : Math.max(1, Math.ceil((expiresAt - now) / (24 * 60 * 60 * 1000))),
    };
  }

  const trialStart =
    row.subscription_trial_started_at == null
      ? null
      : Number(row.subscription_trial_started_at);

  if (trialStart && now - trialStart < TRIAL_MS) {
    return {
      ...base,
      active: true,
      reason: 'trial',
      trialStart,
      daysRemaining: Math.max(
        1,
        Math.ceil((trialStart + TRIAL_MS - now) / (24 * 60 * 60 * 1000)),
      ),
    };
  }

  // Nothing entitlement-shaped in the DB. Before denying, ask the store —
  // store-first truth is what keeps paying users unlocked when the webhook
  // or the /subscription/sync call lags.
  if (verifyRc) {
    const rc = await rcEntitlementActive(uid);
    if (rc.ok && rc.active) {
      return { ...base, active: true, verified: true, reason: 'subscription' };
    }
    if (!rc.ok && rc.configured) {
      // Store API outage: fail open so a paying user is never locked out by
      // our own dependency being down.
      return {
        ...base,
        active: true,
        verified: false,
        reason: 'rc_unavailable',
        trialStart,
        expiresAt,
      };
    }
  }

  if (trialStart) {
    return { ...base, active: false, reason: 'trial_expired', trialStart, expiresAt };
  }

  // No trial on record. A device that already burned a trial on another uid
  // is denied; otherwise only a row old enough that a trial would be over is.
  if (await deviceClaimedElsewhere(uid, row.trial_device_id)) {
    return { ...base, active: false, reason: 'device_claimed' };
  }

  const createdMs = parseSqliteDate(row.created_at);
  const stale = createdMs != null && now - createdMs > TRIAL_MS;
  return {
    ...base,
    active: !stale,
    reason: stale ? 'no_trial_stale' : 'no_trial',
    daysRemaining: stale ? 0 : TRIAL_DAYS,
  };
}

function clearRcCache(uid) {
  if (uid) rcCache.delete(uid);
  else rcCache.clear();
}

module.exports = {
  resolveEntitlement,
  clearRcCache,
  hasActiveSubscription,
  parseSqliteDate,
  TRIAL_DAYS,
};
