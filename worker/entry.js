import { httpServerHandler } from 'cloudflare:node';

const API_PREFIX = '/api/';

let bootState = null;

async function boot(env) {
  if (bootState) return bootState;
  bootState = (async () => {
    for (const [key, value] of Object.entries(env || {})) {
      if (typeof value === 'string' && process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
    process.env.WORKER_RUNTIME = '1';

    const mod = await import('../backend/server.js');
    const { createServer } = mod.createServer ? mod : mod.default;

    // server.js boots asynchronously (initDB() then listen). Await the real
    // http.Server so the first request never races the schema init.
    const server = await createServer();

    return httpServerHandler(server);
  })().catch((error) => {
    bootState = null;
    console.error('[Worker boot failed]', error);
    throw error;
  });
  return bootState;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith(API_PREFIX)) {
      return env.ASSETS.fetch(request);
    }
    const handler = await boot(env);
    return handler.fetch(request, env, ctx);
  },
};
