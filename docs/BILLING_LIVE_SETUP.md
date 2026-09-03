# Billing — Live Setup

Web billing is Paddle + RevenueCat (no Google Play Billing).

## Pricing Model (Locked)

| Plan | Price | Billing Cycle | Shields | Gifting |
|---|---|---|---|---|
| Monthly Challenge $1 | `$1 first 30d` → `$15/mo` | `month:1` | 3 | Single user |
| Monthly Challenge $5 | `$5 first 30d` → `$15/mo` (A/B vs $1) | `month:1` | 3 | Single user |
| 4-Month Journey | `$49.99 / 4 mo` (charm `50→49.99`) | `month:4` (120d) | 18 | Single user |
| Yearly | `$99.99 / yr` (charm `100→99.99`) | `year:1` | 72 | Single user |
| Lifetime — Gift of Allah | `$199` one-time | lifetime | 150 shared | 3 users max, transferable via email |
| Shop Consumable | `$0.99 / streak-shield` | one-time `is_consumable:true` | +1 per purchase | Any user |

**Charm pricing rule:** Bump quarterly and yearly to nearest 50 or 100, minus $0.10 (e.g., `50→49.99`, `100→99.99`).

**Lifetime USP:** "Pass it down to friends and family — like videogame CDs. We won't pull a Rockstar on you." Transferable to 3 family/friends emails via `/api/v2/subscription/transfer`.

**Streak Shields:** Pool of 150 shared among 3 lifetime users (not per-user). Non-lifetime shields are individual (3/18/72). Shields repair streak when `gap > 1 day`.

## Live IDs (as of 2026-09-02)

### RevenueCat Project
- Project: `projd48bfa0c` "Meowmin"
- Entitlement: `Meowmin Max` (`entl04c6421978`)
- RC App (sandbox): `app0b77e301af` "Meowmin Web Paddle" — `paddle_is_sandbox: true`
- RC App (test): `appc521699321` "Test Store" (test_store)

### Paddle Live Products

| Plan | Paddle Product ID | Paddle Price IDs |
|---|---|---|
| Monthly $1 | `pro_01m1h2hshh3dm3sh8mwcctq7k4` | Intro: `pri_01m1h2jbnv7d7xs7eb8a9bswav`, Standard: `pri_01m1h2jbrwd3q4j4bj7cqcfd2v` |
| Monthly $5 | `pro_01m1h2hsn62njvbq47471m962j` | Intro: `pri_01m1h2jbtz4r9rtd5e5c6hcp14`, Standard: *(verify via paddle-live)* |
| 4-Month Journey | `pro_01m1h2hsrwt6a76zqf3hf4w1dn` | `pri_01m1h2jqbb7e3gjym5kqf88b54` |
| Yearly | `pro_01m1h2hsxhjkh7vp5jrzxchabq` | `pri_01m1h2jqe88brc2grgnr20jv80` |
| Lifetime | `pro_01m1h2ht16c4ysjtmt8sg3f98v` | `pri_01m1h2jqghnv9yj6k50fqf0wtr` |
| Streak Shield | `pro_01m1h2ht5j8j55h6e9kwd7rq3t` | *(verify via paddle-live)* |

### RevenueCat Products (linked to Paddle)

| RC Product ID | Display Name | Type | Paddle Product ID |
|---|---|---|---|
| `prodb3731437c6` | Meowmin Monthly $1 | subscription | `pro_01m1h2hshh3dm3sh8mwcctq7k4` |
| `prod650725adcb` | Meowmin Monthly $5 | subscription | `pro_01m1h2hsn62njvbq47471m962j` |
| `prod547e56c8c7` | Meowmin 4-Month Journey | subscription | `pro_01m1h2hsrwt6a76zqf3hf4w1dn` |
| `prodd5c0144a0d` | Meowmin Yearly Plan | subscription | `pro_01m1h2hsxhjkh7vp5jrzxchabq` |
| `prod248011c049` | Meowmin Lifetime Plan | one_time | `pro_01m1h2ht16c4ysjtmt8sg3f98v` |
| `prod26e5529089` | Streak Shield | one_time | `pro_01m1h2ht5j8j55h6e9kwd7rq3t` |

### RevenueCat Offerings

| Offering | Lookup Key | ID | Status | Packages |
|---|---|---|---|---|
| **default_v2** | `default_v2` | `ofrng98cbe84254` | **CURRENT** | 5 |
| **tier-b-v2** | `tier-b-v2` | `ofrngb2a22ce37c` | inactive | 5 |
| ~~default~~ | `default` | `ofrng7101c937b0` | archived | — |
| ~~tier-b~~ | `tier-b` | `ofrngd3c98cc6a4` | archived | — |

#### `default_v2` packages (Monthly $1 flow)

| Package ID | Lookup Key | RC Product | Position |
|---|---|---|---|
| `pkge44fe2a24d0` | `$rc_monthly` | `prodb3731437c6` (Monthly $1) | 1 |
| `pkge105fc94e75` | `$rc_three_month` | `prod547e56c8c7` (4-Month Journey) | 2 |
| `pkgec19227af15` | `$rc_annual` | `prodd5c0144a0d` (Yearly) | 3 |
| `pkge2c4e5f4aed` | `$rc_lifetime` | `prod248011c049` (Lifetime) | 4 |
| `pkge4a6cb33bee` | `$rc_custom_streak_shield` | `prod26e5529089` (Streak Shield) | 5 |

#### `tier-b-v2` packages (Monthly $5 flow)

| Package ID | Lookup Key | RC Product | Position |
|---|---|---|---|
| `pkge8e6bc019bd` | `$rc_monthly` | `prod650725adcb` (Monthly $5) | 1 |
| `pkge9b54393c19` | `$rc_three_month` | `prod547e56c8c7` (4-Month Journey) | 2 |
| `pkgefe3228a959` | `$rc_annual` | `prodd5c0144a0d` (Yearly) | 3 |
| `pkge7975d3ba4d` | `$rc_lifetime` | `prod248011c049` (Lifetime) | 4 |
| `pkge2c4c6bd695` | `$rc_custom_streak_shield` | `prod26e5529089` (Streak Shield) | 5 |

### Experiments

| Exp | ID | Name | Type | Status |
|---|---|---|---|---|
| Exp1 | `exp2850614435` | Tier A vs Tier B | price_point | **stopped** |
| Exp2 | *(not yet created)* | Monthly $1 vs $5 | price_point | pending |

### Sandbox Inventory (legacy — no longer used for new products)

- `pro_01kywxnjkbcxc9rtmgeds1ne6q` "Meowmin" — lifetime, yearly, monthly
- `pro_01m1eqyb020s1fzzs6cnwbnqm8` "Meowmin Tier B" — yearly, monthly
- Paddle webhook `ntfset_01kyyadq6jg2jgwxj1c6yej29h` → sandbox RC (active)

## Backend endpoints (done)

- `POST /api/v2/subscription/sync` — RevenueCat verify + shield awards on first active subscription
- `POST /api/v2/subscription/transfer` — Lifetime subscribers invite up to 2 family/friends via email
- `GET /api/v2/subscription/shields` — Returns user's `shield_balance`
- `POST /api/v2/shop/shield-grant` — Grants 1 shield after RevenueCat consumable purchase
- `POST /api/v2/shop/shield-consume` — Consumes shields to repair streak (input: `daysGap`)

## App wiring (done)

- `lib/services/revenuecat_service.dart` — requires live keys via `--dart-define` in release. Debug falls back to sandbox constants only in `kDebugMode`. Inject both:
  - `REVENUECAT_API_KEY` (native live)
  - `REVENUECAT_WEB_API_KEY` (web live, `pdl_live_...`)
- `lib/services/streak_service.dart` — shields logic: `getShieldBalance()`, `consumeShields(daysGap)`, auto-shield in `checkAndUpdateStreak()` when gap > 1
- `lib/screens/web_paywall_screen.dart` — fetches `offerings.current` (resolves to `default_v2`), shield badges, plan copy, CTA
- `backend/routes/subscription.js` — RC verify + shield awards + transfer + shields endpoint
- `backend/routes/shop.js` — shield-grant + shield-consume endpoints
- `backend/.env.example` — documents all required env vars

## Steps to go live

1. ~~Create live Paddle products~~ ✅ (6 products, 8 prices created via `paddle-live_execute`)
2. ~~Create RC products + offerings~~ ✅ (`default_v2` and `tier-b-v2` with 5 packages each)
3. ~~Archive old offerings~~ ✅ (`default` and `tier-b` archived)
4. **Create Exp2** — $1 vs $5 monthly challenge experiment (pending)
5. **Verify truncated Paddle price IDs** — Monthly $5 Standard + Shield prices (pending)
6. **Domain approval**: Paddle Checkout → Default payment link → approve `meowmin.taucity.xyz` (required — sandbox auto-approves, live does not)
7. **Paddle webhook**: Create live webhook in Paddle → RevenueCat endpoint
8. **Keys**: From Paddle vendors → Developer tools → Authentication copy `pdl_live_apikey_...`; from RevenueCat → API Keys copy web key
9. **Deploy**:
   ```bash
   # Flutter web (live)
   flutter build web --release \
     --dart-define=REVENUECAT_API_KEY=... \
     --dart-define=REVENUECAT_WEB_API_KEY=pdl_live_... \
     --dart-define=BACKEND_BASE_URL=https://meowmin.taucity.xyz/api/v2

   # Backend env (Cloudflare)
   REVENUECAT_API_SECRET=...
   PADDLE_API_KEY=pdl_live_apikey_...
   PADDLE_NOTIFICATION_WEBHOOK_SECRET=pdl_ntfset_...
   ALLOWED_ORIGINS=https://meowmin.taucity.xyz,https://taucity.xyz
   ```
10. **Verify**: Real card test, RevenueCat Transactions visible, `hasActiveEntitlement('Meowmin Max')` true, `POST /subscription/sync` verified. See https://developer.paddle.com/build/go-live-checklist

## Payouts

Live only — verify bank in Paddle live → Payouts before launch. Sandbox has no payouts.
