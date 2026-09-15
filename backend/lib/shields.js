/**
 * Plan -> Streak Shield allowance.
 *
 * One source of truth for both grant paths (RevenueCat `/subscription/sync`
 * and the Paddle webhook) — they had drifted into two different tables, so a
 * plan could be worth 18 shields in one and 0 in the other.
 *
 * Ids are matched as substrings because they differ per storefront and era:
 * Play sells `meowmin_yearly` / `meowmin_4month` / `meowmin_monthly`, while
 * RC/Paddle catalogue rows carry long-form ids (`$rc_annual`,
 * `four-month-journey`, `lifetime-gift`). Order matters: the 4-month match
 * must beat any monthly fallback.
 */
const PLAN_SHIELDS = [
  { match: ['lifetime'], shields: 150 },
  { match: ['four-month', 'four_month', 'fourmonth', '4month'], shields: 18 },
  { match: ['yearly', 'year', 'annual', '12-month', '12month'], shields: 72 },
  { match: ['monthly-challenge-1', 'monthly-challenge-5'], shields: 3 },
];

/** The $0.99 repeatable consumable: one shield per purchase. */
const SHIELD_PRODUCT_MATCHES = [
  'streak-shield',
  'streak_shield',
  'meowmin_shield',
];

const CONSUMABLE_SHIELDS = 1;

/** Plan allowance for a subscription product id. 0 for anything else. */
function shieldsForProduct(productId) {
  if (!productId) return 0;
  const id = String(productId).toLowerCase();
  for (const award of PLAN_SHIELDS) {
    if (award.match.some((m) => id.includes(m))) return award.shields;
  }
  return 0;
}

function isShieldConsumable(...ids) {
  const hay = ids.filter(Boolean).join(' ').toLowerCase();
  if (!hay) return false;
  return SHIELD_PRODUCT_MATCHES.some((m) => hay.includes(m));
}

/**
 * Paddle one-time path: a shield consumable grants exactly one shield,
 * otherwise fall back to the plan table (lifetime etc. arrive as a single
 * transaction there).
 */
function shieldsForPrice(priceId, productId) {
  if (isShieldConsumable(priceId, productId)) return CONSUMABLE_SHIELDS;
  return shieldsForProduct(`${priceId || ''} ${productId || ''}`);
}

module.exports = {
  PLAN_SHIELDS,
  CONSUMABLE_SHIELDS,
  shieldsForProduct,
  shieldsForPrice,
  isShieldConsumable,
};
