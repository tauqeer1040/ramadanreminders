// meowmin-cron: reliable heartbeat for AI insight generation.
//
// Why this exists: the API runs on Cloudflare Pages (Workers runtime), where
// setInterval doesn't tick between requests and fire-and-forget promises may
// never execute. This tiny scheduled Worker POSTs to poll-ai every 5 minutes
// so pending journals always get picked up, even with zero app traffic.
//
// Setup (one time):
//   cd cron
//   npx wrangler deploy
//   printf '%s' "$INTERNAL_POLL_SECRET" | npx wrangler secret put INTERNAL_POLL_SECRET
//
// Verify:
//   npx wrangler tail meowmin-cron   # watch for "[cron] poll-ai -> 202"
//   Trigger manually: dashboard -> Workers & Pages -> meowmin-cron -> Settings
//   (cron triggers show last/next run).
export default {
  async fetch() {
    return new Response('meowmin-cron ok', {
      status: 200,
      headers: { 'content-type': 'text/plain' },
    });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(triggerPoll(env, event.cron));
  },
};

async function triggerPoll(env, cron) {
  const res = await fetch(`${env.API_BASE}/api/v2/internal/poll-ai`, {
    method: 'POST',
    headers: { 'x-internal-secret': env.INTERNAL_POLL_SECRET },
  });
  console.log(`[cron] poll-ai -> ${res.status} (schedule: ${cron})`);
  if (!res.ok) {
    throw new Error(`poll-ai returned ${res.status}`);
  }
}
