// Execution-context plumbing for Cloudflare Workers.
//
// Problem: on Workers, work scheduled AFTER the response (setTimeout,
// fire-and-forget promises) may never run — the isolate can suspend as soon
// as the response completes. The reliable primitive is ctx.waitUntil(),
// but Express handlers (via cloudflare:node httpServerHandler) never see ctx.
//
// Solution: worker/entry.js runs every fetch inside this AsyncLocalStorage,
// so any backend code can access the ctx and extend the invocation lifetime.
// Outside Workers (plain Node/VPS/local dev) there is no ctx and callers
// fall back to detached execution, preserving old behavior.
//
// Usage:
//   const { runAfterResponse } = require('../lib/request-context');
//   runAfterResponse(() => pollPendingJournals(), {
//     fallback: () => scheduleProcessSoon(),
//   });
const { AsyncLocalStorage } = require('async_hooks');

const als = new AsyncLocalStorage();

function runWithContext(ctx, fn) {
  return als.run(ctx || {}, fn);
}

function getContext() {
  try {
    return als.getStore();
  } catch (_) {
    return undefined;
  }
}

/**
 * Run an async job after the HTTP response without losing it on Workers.
 * Returns 'waitUntil' | 'fallback' | 'detached'. Never throws.
 */
function runAfterResponse(jobFactory, opts) {
  const onError =
    opts && typeof opts.onError === 'function' ? opts.onError : null;
  const report = (where, e) => {
    console.error(`[waitUntil] ${where} failed:`, e.message);
    try {
      if (onError) onError(e);
    } catch (_) {}
  };
  try {
    const ctx = getContext();
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(
        Promise.resolve()
          .then(jobFactory)
          .catch((e) => report('background job', e))
      );
      return 'waitUntil';
    }
    if (opts && typeof opts.fallback === 'function') {
      try {
        opts.fallback();
      } catch (e) {
        report('fallback', e);
      }
      return 'fallback';
    }
    Promise.resolve()
      .then(jobFactory)
      .catch((e) => report('detached job', e));
    return 'detached';
  } catch (e) {
    report('scheduling', e);
    return 'error';
  }
}

module.exports = { runWithContext, getContext, runAfterResponse };
