# meowmin-cron

Dedicated scheduled Worker that keeps AI insight generation moving.

## Why

The API serves from Cloudflare Pages (Workers runtime):

- `setInterval` does not tick without traffic.
- Fire-and-forget promises after a response may never run (fixed for
  `poll-ai` via `ctx.waitUntil`, but belt-and-braces needs a real trigger).

This worker POSTs to `poll-ai` every 5 minutes. The endpoint returns 202
immediately and does the work past the response via `waitUntil`.

## Deploy

```bash
cd cron
npx wrangler deploy
printf '%s' "$INTERNAL_POLL_SECRET" | npx wrangler secret put INTERNAL_POLL_SECRET
```

Use the same `INTERNAL_POLL_SECRET` value as the Pages project
(`backend/.env`, never committed).

## Verify

```bash
npx wrangler tail meowmin-cron
# expect "[cron] poll-ai -> 202" every 5 minutes
```

Dashboard: Workers & Pages → meowmin-cron → Settings shows last/next cron run.

## Notes

- The poller is single-flight + lease-guarded, so overlapping triggers
  (this cron, GitHub Actions `poll-ai.yml`, sync nudges) are harmless.
- If this worker ever goes quiet, pending journals pile up as
  `ai_status='pending'` — watch `GET /internal/decks/health`.
