# Email-Continuation Signup — Meowmin (Netflix-style)

**Status:** v3 approved, implementation in progress · **Companion model:** no
purchase UI, prices, or checkout links ever render on Android. Conversion
happens off-device via email → Paddle web checkout. Zero Google cut.

**Goal:** convert Android trial users to Paddle web checkout. Last onboarding
steps: **mandatory Google OAuth (step −1)** → **"Check your email" finale**.
The email delights with the user's own data (spiritual profile card, their
journal, their AI insights) + 2 CTAs (top + bottom) into personalized
`/pricing`. Skippable for the 3-day trial; mandatory hard gate after.

## 1. User flow (screens)

1. `Onboarding → … → Celebration → Summary → [MANDATORY] GoogleSignInPage`
   - No skip routes (`_skipToLogin` removed). Cancelled/failed OAuth →
     retry-only screen, no forward path.
   - On success: `RevenueCatService.instance.identify(firebaseUid)` (linchpin:
     without this, web purchases linked by email never light up Pro in-app),
     backend upserts `users(email, firebase_uid, rc_customer_id)`, mints
     continue-token, sets RC `$email` attribute.
2. `[NEW] CheckEmailScreen` (finale, trial-aware — reads `TrialService`
   `graceMs`, the single trial clock)
   - **Trial active (days 0–3):** "Check your email — we sent `m•••@gmail.com`
     a link to finish setup." Primary **Open email app** (`CATEGORY_APP_EMAIL`
     intent; fallback copy-address + Gmail/Outlook chips). Skip link:
     "Continue without email — *X* left". Max 1 full prompt/day
     (`lastEmailPromptDay`) + prompt on gate dismiss. Copy ladder: day 0
     "finish setup when ready" → day 1 "your profile card is waiting" →
     day 2 "trial ends tomorrow — streak at risk" → day 3 "last chance".
     Resend (60s cooldown, 5/day), Edit email (revokes old token),
     "I already subscribed → Sign in". Dismissible; full trial access kept.
   - **Trial expired (`graceMs <= 0`): HARD GATE** (replaces hard-paywall
     branch). `PopScope(canPop:false)`, no dismiss/continue. Exits only:
     (a) purchase detected via status polling → celebration unlock;
     (b) pre-existing Max via sign-in/restore; (c) resend/edit/open-mail;
     (d) support contact link. Headline: "Your trial ended — check your
     email to continue."
3. Email → personalized `/pricing?email=…&tok=…` → Paddle overlay (email
   prefilled, attribution in `custom_data`) → celebration → deep link back.

## 2. Backend (new + touched)

- **Provider (new dep): Resend** (simple API, free tier, good deliverability).
  Configure via env (`RESEND_API_KEY`); code ships complete, sending needs
  the key + SPF/DKIM DNS (launch-critical for the hard gate).
- `POST /api/email-continue { email, firebase_uid, name, consent_updates }`
  (also auto-fired post-OAuth): zod-validate, rate-limit, upsert `users`,
  create-or-reuse RC-customer mapping (`email ↔ firebase_uid ↔
  rc_customer_id`), mint opaque single-use token 24h TTL
  (`continue_tokens`: `tok_hash, email, rc_customer_id, expires_at,
  consumed_at`), send delight email. Never log raw tokens (hash only).
- `GET /api/continue-status?tok=…` → `{ purchased: bool }`.
- `POST /api/email-continue/resend` (server-side cooldown).
- **Touched `paddleWebhook.js`:** read `custom_data.app_user_id` /
  `continue_token` → resolve user → mark consumed → run existing RC grant
  flow for that customer; log to `webhook_events`.
- **Touched `subscription.js`:** status resolves by token as well as UID.

## 3. Paddle contract

- `pricing.astro`: `customer.email` prefill from query; `custom_data:
  { app_user_id, continue_token, source: 'onboarding-email' }`.
- Token single-use, 24h TTL; webhook idempotency unchanged.

## 4. RevenueCat mapping

- Logged-out/anon trial user: backend owns `rc_customer_id`; app caches
  locally. On Google Sign-In, `identify(firebaseUid)` aliases (RC `logIn`
  merges) — webhook-attached purchases resolve to the same customer, Max
  appears on next `getCustomerInfo`. `$email` set at mint.

## 5. App changes (Flutter)

- `GoogleSignInPage`: add `identify()` post-success; remove skip routes in
  `onboarding_screen.dart`.
- New `CheckEmailScreen` (soft/hard branches bound to `graceMs`);
  `android_intent_plus` (new dep) for mail intent + fallbacks; secure-store
  `continue_tok`/`continue_email`; 10s status polling (≤10 min) with backoff;
  return deep-link handler.
- `PaywallGateScreen` hard branch → mandatory check-email content.
- `final_pages.dart` `openStoreListing` wrapped in try/catch (ratings flow).

## 6. Delight email spec (v2)

- Subject: "Finish setting up Meowmin — your trial is ready"
- **CTA #1 (top):** "Continue setup — claim your 3-day trial →"
  (personalized pricing link).
- **Spiritual Profile card** (branded HTML): name, intention quote
  (`OnboardingData.intentionAnswer`), day-1 streak seal, time spent
  (`_formatTimeSpent(startTime)`), verses-met count, signature verse
  (Arabic + transliteration + English).
- **"Your first journal"**: entry excerpt (queried by session `startTime`)
  + its 3 AI insights + matched story refs.
- **CTA #2 (bottom):** "Keep walking — pick your pace →" + no-card trial
  reassurance + contact footer + marketing unsubscribe (transactional always
  allowed). Existing-subscriber variant: "Max is already on this email —
  just sign in."
- Day-2 nudge + expiry win-back reuse the link format.

## 7. Edge cases

Existing subscriber → sign-in variant; typo → edit revokes old token;
expired/consumed → inline error + resend; no mail app → chips (no crash);
offline submit → queued retry; duplicate RC customers → mapping-table first;
reinstall → server `users` row keeps trial/email state (idempotent);
back-button/restart vs hard gate → no bypass (`canPop:false` + server clock).

## 8. Compliance (companion model)

Zero purchase UI/prices/checkout links on Android — enforced by grep audit.
Mail-client intent is not a purchase link. Listing/review notes never
describe the email-to-web mechanics. Consent checkbox; policy already
discloses email use (confirm marketing-toggle wording matches).

## 9. Metrics (GA4, extend `analytics_protocol.dart`)

`oauth_mandatory_completed`, `email_continue_sent/resent`,
`email_check_skipped`, `email_prompt_shown/dismissed`, `email_app_opened`,
`trial_expired_hard_gate`, `gate_unlocked_purchased`,
`web_purchase_attributed(source=onboarding-email, hashed)`.

## 10. Rollout & acceptance

1. Resend key + SPF/DKIM → inbox delivery test.
2. Endpoints + migration + webhook attribution; staging: submit → receive →
   sandbox buy → reopen → Max on.
3. 10% holdout (old finale) vs email finale; success = email→purchase ≥
   baseline trial→gate conversion.
4. Day-0 skip → full trial; simulated day-4 → hard gate, no bypass;
   purchase → unlock ≤ polling interval; existing Max never gated.
5. Cross-link `BILLING_LIVE_SETUP.md`.

## 11. Build list (this run — done except where noted)

- [x] `identify()` in `GoogleSignInPage`; Continue gated on login
      (skip-forward-to-login kept — lands on the mandatory page)
- [x] `CheckEmailScreen` + gate hard-branch swap + polling + mail intent
      (MethodChannel `openEmailApp`, no new pub dep)
- [x] Backend endpoints + `continue_tokens` migration + webhook attribution
      + Resend service (needs `RESEND_API_KEY` + SPF/DKIM to actually send)
- [x] try/catch `openStoreListing`; legal-link domains; about payments line;
      location copy/policy alignment; version `1.0.0+2`
- [x] `flutter analyze` zero errors on touched files; backend `node --check`
      green + route-registration smoke test green
- [ ] Play Console listing edits (dashboard, 1 min): "Meowmin Pro"→"Max",
      drop "thousands" — MCP skips listing-text writes by policy here
- [ ] Backend jest suite + staging end-to-end (submit → email → sandbox buy
      → reopen → Max on) once `RESEND_API_KEY` is set
