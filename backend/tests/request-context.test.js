// Unit tests for waitUntil plumbing (no DB, no network).
const {
  runWithContext,
  getContext,
  runAfterResponse,
} = require('../lib/request-context');

describe('request-context', () => {
  test('no context without runWithContext', () => {
    expect(getContext()).toBeUndefined();
  });

  test('waitUntil path when ctx present', async () => {
    let ran = false;
    const waited = [];
    const ctx = { waitUntil: (p) => waited.push(p) };
    const mode = runWithContext(ctx, () =>
      runAfterResponse(
        () =>
          new Promise((resolve) =>
            setTimeout(() => {
              ran = true;
              resolve();
            }, 10)
          )
      )
    );
    expect(mode).toBe('waitUntil');
    await Promise.all(waited);
    expect(ran).toBe(true);
  });

  test('fallback path on plain Node', () => {
    let fallbackRan = false;
    const mode = runAfterResponse(() => Promise.resolve(), {
      fallback: () => {
        fallbackRan = true;
      },
    });
    expect(mode).toBe('fallback');
    expect(fallbackRan).toBe(true);
  });

  test('detached path without fallback', async () => {
    const mode = runAfterResponse(() => Promise.resolve());
    expect(mode).toBe('detached');
    await new Promise((r) => setTimeout(r, 20));
  });

  test('onError receives background failures, never throws', async () => {
    const seen = [];
    const waited = [];
    const ctx = { waitUntil: (p) => waited.push(p) };
    runWithContext(ctx, () =>
      runAfterResponse(() => Promise.reject(new Error('boom')), {
        onError: (e) => seen.push(e.message),
      })
    );
    await Promise.allSettled(waited);
    expect(seen).toEqual(['boom']);
  });

  test('broken ctx does not throw the request', () => {
    const ctx = {
      waitUntil: () => {
        throw new Error('ctx dead');
      },
    };
    expect(() =>
      runWithContext(ctx, () => runAfterResponse(() => Promise.resolve()))
    ).not.toThrow();
  });
});
