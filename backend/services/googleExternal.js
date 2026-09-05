// Google Play External Transactions reporting (External Offers program, EEA).
// Reports Paddle transactions that followed an in-app external offer link-out
// so Google can invoice the service fee (10% subs / 10% one-time under $1M).
// Never throws to callers on API failure — returns {ok:false, error} and the
// caller persists the outcome to google_external_reports for ops retry.
//
// API: POST /androidpublisher/v3/applications/{pkg}/externalTransactions
//      ?externalTransactionId={id}  (scope: androidpublisher)
// Ref: developers.google.com/android-publisher/api-ref/rest/v3/externaltransactions
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PACKAGE = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.taucity.meowmin';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';

let saCache = null;
let tokenCache = null; // { token, expMs }

function loadServiceAccount() {
  if (saCache) return saCache;
  const p = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_PATH
    || path.resolve(__dirname, '..', '..', 'android', 'fastlane', 'play-developer-api.json');
  const raw = fs.readFileSync(p, 'utf8');
  saCache = JSON.parse(raw);
  if (!saCache.client_email || !saCache.private_key) {
    throw new Error('googleExternal: service account JSON missing client_email/private_key');
  }
  return saCache;
}

function b64url(bufOrStr) {
  return Buffer.from(bufOrStr).toString('base64url');
}

async function getAccessToken() {
  const now = Date.now();
  if (tokenCache && tokenCache.expMs - 60000 > now) return tokenCache.token;
  const sa = loadServiceAccount();
  const iat = Math.floor(now / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  const signature = signer.sign(sa.private_key, 'base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${signature}`,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.access_token) {
    throw new Error(`googleExternal: oauth token failed (${res.status}): ${JSON.stringify(json).slice(0, 300)}`);
  }
  tokenCache = { token: json.access_token, expMs: now + (Number(json.expires_in) || 3600) * 1000 };
  return tokenCache.token;
}

async function apiPost(pathSuffix, body) {
  const token = await getAccessToken();
  const res = await fetch(`${API_BASE}${pathSuffix}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(`googleExternal: API ${res.status}: ${JSON.stringify(json).slice(0, 500)}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

// Paddle smallest-unit (cents) -> Google micros string. Paddle totals arrive as
// integer strings ("4999" = $49.99). 1 cent = 10,000 micros.
function centsToMicrosStr(cents) {
  const n = Number(cents || 0);
  if (!Number.isFinite(n) || n < 0) return '0';
  return String(Math.round(n * 10000));
}

/**
 * Report one charge.
 * kind: 'one_time' | 'recurring_initial' | 'recurring_subsequent'
 * - token (PBL externalTransactionToken): required for one_time + recurring_initial.
 * - initialId: required for recurring_subsequent (first txn id of the series).
 */
async function reportExternalTransaction({
  externalTransactionId,
  preTaxMicros,
  taxMicros,
  currency,
  regionCode,
  transactionTime,
  kind,
  token,
  initialId,
}) {
  if (!externalTransactionId || !/^[A-Za-z0-9_-]{1,63}$/.test(externalTransactionId)) {
    throw new Error('googleExternal: invalid externalTransactionId');
  }
  if (kind !== 'one_time' && kind !== 'recurring_initial' && kind !== 'recurring_subsequent') {
    throw new Error('googleExternal: invalid kind');
  }
  if ((kind === 'one_time' || kind === 'recurring_initial') && !token) {
    throw new Error('googleExternal: token required for initial/one-time report');
  }
  if (kind === 'recurring_subsequent' && !initialId) {
    throw new Error('googleExternal: initialId required for subsequent recurring report');
  }
  const body = {
    originalPreTaxAmount: { currency, priceMicros: String(preTaxMicros) },
    originalTaxAmount: { currency, priceMicros: String(taxMicros) },
    transactionTime,
    userTaxAddress: { regionCode },
  };
  if (kind === 'one_time') {
    body.oneTimeTransaction = { externalTransactionToken: token };
    body.externalOfferDetails = { linkType: 'LINK_TO_DIGITAL_CONTENT_OFFER' };
  } else if (kind === 'recurring_initial') {
    body.recurringTransaction = {
      externalSubscription: { subscriptionType: 'RECURRING' },
      externalTransactionToken: token,
      initialExternalTransactionId: externalTransactionId,
    };
    body.externalOfferDetails = { linkType: 'LINK_TO_DIGITAL_CONTENT_OFFER' };
  } else {
    body.recurringTransaction = {
      externalSubscription: { subscriptionType: 'RECURRING' },
      initialExternalTransactionId: initialId,
    };
  }
  const qs = `?externalTransactionId=${encodeURIComponent(externalTransactionId)}`;
  return apiPost(`/applications/${PACKAGE}/externalTransactions${qs}`, body);
}

/** Full refund of a previously reported transaction. Partial refunds: pass partialRefund. */
async function refundExternalTransaction({ externalTransactionId, refundTime, partialRefund } = {}) {
  if (!externalTransactionId) throw new Error('googleExternal: refund needs externalTransactionId');
  const body = { refundTime: refundTime || new Date().toISOString() };
  if (partialRefund) {
    body.partialRefund = partialRefund; // { refundPreTaxAmount:{currency,priceMicros}, refundTaxAmount:{...} }
  } else {
    body.fullRefund = {};
  }
  const p = `/applications/${PACKAGE}/externalTransactions/${encodeURIComponent(externalTransactionId)}:refund`;
  return apiPost(p, body);
}

// Service-fee estimate in micros for the finance ledger (not billed by us —
// Google invoices). Subs 10%; one-time 10% while under the first-$1M tier.
function estimateFeeMicros(kind, preTaxMicrosStr) {
  const n = Number(preTaxMicrosStr || 0);
  if (!Number.isFinite(n) || n <= 0) return 0;
  void kind;
  return Math.round(n * 0.10);
}

module.exports = {
  reportExternalTransaction,
  refundExternalTransaction,
  estimateFeeMicros,
  centsToMicrosStr,
  packageName: PACKAGE,
};
