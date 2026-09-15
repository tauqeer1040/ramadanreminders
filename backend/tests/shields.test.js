// Plan -> shield allowance mapping, checked against the SKUs the stores really
// expose (Play: meowmin_yearly / meowmin_4month / meowmin_monthly, verified via
// the Play Developer API).
// Run: npx jest tests/shields.test.js --forceExit
const { shieldsForProduct } = require('../routes/subscription');

test('Play yearly plan grants the 12-month allowance', () => {
  expect(shieldsForProduct('meowmin_yearly')).toBe(72);
});

test('Play 4-month plan grants its allowance, not the monthly fallback', () => {
  expect(shieldsForProduct('meowmin_4month')).toBe(18);
});

test('monthly plan does not grant plan shields', () => {
  expect(shieldsForProduct('meowmin_monthly')).toBe(0);
});

test('lifetime grants the lifetime allowance', () => {
  expect(shieldsForProduct('meowmin_lifetime')).toBe(150);
});

test('RevenueCat/Paddle catalogue ids still map', () => {
  expect(shieldsForProduct('four-month-journey')).toBe(18);
  expect(shieldsForProduct('$rc_annual')).toBe(72);
  expect(shieldsForProduct('monthly-challenge-1')).toBe(3);
});

test('unknown and empty ids grant nothing', () => {
  expect(shieldsForProduct('')).toBe(0);
  expect(shieldsForProduct(null)).toBe(0);
  expect(shieldsForProduct('meowmin_shield')).toBe(0);
});
