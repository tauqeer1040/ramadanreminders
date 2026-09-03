# Play Store Submission Readiness — Meowmin Ai Diary

**App Name:** Meowmin Ai Diary  
**Package:** `com.taucity.meowmin`  
**Version:** `1.0.0+1`  
**Date:** 2026-05-30  

---

## 1. Feature & Risk Inventory

| Feature | Risk Level | Notes |
|---------|-----------|-------|
| User journal entries (UGC) | **High** | Users write daily reflections stored on backend (Turso). Needs moderation capability. |
| AI-generated insights | Medium | OpenRouter generates Islamic reflections from journal text. |
| Quran verse display | Low | Proxied from alquran.cloud. |
| Prayer times (geolocation) | **Medium** | Uses `ACCESS_FINE_LOCATION` via geolocator for adhan calculation. |
| Daily notifications | Low | Suhoor/iftar/night reminders via `flutter_local_notifications`. |
| Paddle + RevenueCat subscription (Meowmin Max) | **Medium** | $1 first 30d → $15/mo, 4-Mo $49.99, Yearly $99.99, Lifetime $199. Paywall via RevenueCat Customer Center on web (`/pricing` Paddle Overlay) + native `WebPaywallScreen`. Supports Pause (Customer Center → Pause 1-3 months). |
| Home screen streak widget | Low | Read-only widget, no permissions. |
| Audio player (Quran recitations) | Low | Streams audio from alquran.cloud. |
| Google Sign-In | Low | Optional auth via Firebase + google_sign_in. |
| Tasbih/dhikr counter | Low | Local only. |

---

## 2. Data Safety Form — Required

### SDK Inventory

| SDK | Data Collected | Purpose | Shared With Third Parties |
|-----|---------------|---------|--------------------------|
| Firebase Auth | Email, UID, auth tokens | User authentication | No (Google infra) |
| Turso (LibSQL) + Cloud Firestore (legacy) | Encrypted journal data, user profile | Journal storage (encrypted) | No |
| Fanar / OpenRouter | Diary text per request | AI Islamic insights (not stored) | No |
| Paddle.com Market Ltd | Email, billing address, payment method | Web Merchant of Record, VAT/tax, receipts, refunds (`PADDLE.NET* MEOWMIN`) | Yes — Paddle processes payments |
| RevenueCat | App user ID, entitlement `Meowmin Max`, purchase events, expiry | Paywall + entitlement sync + Customer Center (pause/cancel/restore) | No (RevenueCat infra) |
| Google Sign-In | Name, email, profile photo (if used) | Social login | No |
| Geolocator | Precise location | Prayer time calculation | No |
| flutter_local_notifications | None | Local notifications | No |
| audioplayers | None | Audio playback | No |
| http | None | Backend API calls | No |
| shared_preferences | None | Local cache | No |

### Privacy Policy Must Cover
- What data is collected (journal entries encrypted in Turso, location for prayer times only local, email if signed in)
- How AI (Fanar/OpenRouter) processes journal text per-request (not retained)
- Third parties: Paddle.com Market Ltd (MoR for web: email, billing address, payment method, VAT), RevenueCat (entitlement sync), Google Firebase Auth, Turso
- Data deletion: Profile → Manage Account → Delete My Account (30d purge) + via `contact@taucity.xyz` / `/delete-account`
- Contact email + link in-app Profile → About and on `meowmin.taucity.xyz/privacy, /terms, /refund`

### Critical: No privacy policy URL found in app
Add a privacy policy URL and link it in-app (Settings/Profile page) and in Play Console.

---

## 3. Permissions Audit

| Permission | Declared | Used | Notes |
|-----------|----------|------|-------|
| `ACCESS_FINE_LOCATION` | Yes | Yes | For prayer times. Requested at onboarding, cached. App works without it. |
| `ACCESS_COARSE_LOCATION` | Yes | Yes | Same as above. |
| `POST_NOTIFICATIONS` | Yes | Yes | For suhoor/iftar/night reminders. Requested at onboarding + in profile. |
| `SCHEDULE_EXACT_ALARM` | Commented out | No | Remove from manifest if unused. |

### Permission Request Flow
- **Location:** Onboarding → user toggles "Automatic prayer times" → `Geolocator.requestPermission()` is called (line 38 of `prayer_time_service.dart`). If denied, prayer times use cached coords or return null gracefully.
- **Notifications:** Onboarding → user toggles notifications → `requestPermissions()` called. Also has retry in Profile page.

**Compliance:** Permission gating is in place. Both have fallbacks. Good.

---

## 4. Build & SDK Hygiene

| Setting | Value | Status |
|---------|-------|--------|
| `compileSdk` | 36 | ✅ Current |
| `minSdk` | 26 | ✅ Adequate for Play requirements |
| `targetSdk` | Flutter default (likely 34+) | ⚠️ Verify at build time |
| `namespace` | `com.taucity.meowmin` | ✅ |
| Signing | Debug key (release config) | ❌ **NEEDS FIX** — debug signing line 46 |

### Action Required
1. Set up release signing config (keystore + release signing in `build.gradle.kts`)
2. Rebuild with `flutter build appbundle --release`
3. Enable Play App Signing in Play Console

---

## 5. UGC Policy Compliance

Journals are user-generated content. Play requires:
- **In-app reporting:** ❌ Not implemented. Users cannot report journal content.
- **Moderation capability:** ❌ No admin moderation UI. Journals could contain anything.
- **Filtering/blocking:** ❌ Not implemented.

**Risk:** This is the highest rejection risk. Implement an abuse reporting flow and consider content filtering.

### Minimum Viable
- Add a "Report" option on journal entries in the profile/history view
- Provide a moderation email in the app description
- State in ToS that content must abide by Islamic guidelines

---

## 6. Monetization — Paddle + RevenueCat (Meowmin Max)

| Requirement | Status | Notes |
|------------|--------|-------|
| Price shown before purchase | ✅ | RevenueCat paywall + `/pricing` Paddle overlay show $1→$15/mo, $49.99/4mo, $99.99/yr, $199 lifetime before purchase |
| Clear subscription terms | ✅ | `pricing.astro` + paywall show billing interval, renewal, `PADDLE.NET* MEOWMIN`, VAT at checkout, auto-renew until cancel |
| Restore purchases | ✅ | `Manage Account → Manage Subscription → Restore Purchases` via `RevenueCatService.presentCustomerCenter()` + `restorePurchases()` |
| Cancel / Pause path | ✅ | `Profile → Manage Account → Manage Subscription` → Customer Center → Pause (emphasized gold card), Cancel, Change Plan; also `Profile → Manage Account → Manage Subscription` pause highlight |
| Trial auto-renew warning | ✅ | 3-day trial (no card) + $1 Starter trial → $15/mo warning on pricing + paywall |
| Scarcity tactics ("300 slots") | ✅ Removed | Slot counter removed from onboarding (commit `CelebrationPage:1165` warning box remains only as soft capacity note, not paywall) |

### RevenueCat + Paddle Configuration
- **Entitlement:** `Meowmin Max` (`entl04c6421978`) in project `projd48bfa0c`
- **Offerings:** `default_v2` (current) + `tier-b-v2`, Paddle live products `pro_01m1h2…`
- **Customer Center:** Enable **Pause** (1-3 mo) in RevenueCat Dashboard → Customer Center → Support; Play Console → Monetize → Subscriptions → Allow pause
- **Paddle Default payment link:** `https://meowmin.taucity.xyz/pricing#plans` (approved domain `meowmin.taucity.xyz`)

---

## 7. Store Listing

### App Title
Meowmin Ai Diary

### Screenshots
Ensure screenshots match actual UI:
- Onboarding with paywall pages
- Quran page with scratch cards
- Journal entry bottom sheet
- Profile page

### Description — Red Flags to Avoid
- ❌ "Best app ever" or unverifiable claims
- ❌ Any health/weight loss claims
- ❌ "Free" in title if it requires subscription
- ✅ Describe as "Ramadan journal with AI-powered insights and prayer time tracking"

---

## 8. Content Rating (IARC)

Must answer **Yes** to:
- UGC present (users write journal entries)
- Location used (for prayer times)

---

## 9. Review Notes — Use This in Play Console

```markdown
## Test Account
Email: reviewer@meowmin.app (create a Firebase test account, Meowmin Max active)
Password: MeowminReview2026! (provide in Play Console → Testers)

## Sensitive Features
1. Location permission
   - Used for automatic prayer time calculation
   - Path: Onboarding → "Automatic prayer times based on your location"
   - If denied: app uses cached location or shows generic prayer times
   - Can also be toggled: Profile → Prayer location

2. Notification permission
   - Used for suhoor, iftar, and night reflection reminders
   - Path: Onboarding → notification toggle
   - If denied: can re-enable from Profile → Enable notifications

3. Subscription (Paddle + RevenueCat Meowmin Max)
   - Web: `/pricing` shows $1 first 30d → $15/mo, $49.99/4mo (114 Surahs · 120 Days), $99.99/yr (30 Juz · 12 Months, Recommended), $199 Lifetime (150 shared shields, 3 users), $0.99 shield
   - Native: `Profile → Manage Account → Manage Subscription` → Customer Center (view plan, expiry, Manage → Pause up to 3 mo, Cancel, Change Plan, Restore)
   - Trial: 3-day free trial (no card, 280 chars) in app; paywall after trial or via Profile → Subscribe
   - Guest users: 3-day trial period, not entry-limited, before paywall gate (PaywallGateScreen)
   - Manage path: Profile (tab) → Email row → Manage Account → Subscription card → Manage Subscription → Customer Center

## Special Instructions
- First launch shows 19-step onboarding (Welcome → Music → Name → Intention → … → First Journal → AiInsight scratch cards → Celebration → Summary)
- AI insights may take 30–60 seconds after journaling; scratch cards reveal 3 AI insights per journal
- Backend: https://meowmin.taucity.xyz/api/v2 (Turso + Paddle webhook at /api/paddle-webhook)
- Journals sync when app opens or at midnight; delete via Profile → Manage Account → Delete My Account (30d purge)
- UGC: Journals are private UGC. Report via Profile → Delete Account or email contact@taucity.xyz (see Privacy Data Deletion)

## Privacy Policy
https://meowmin.taucity.xyz/privacy
## Terms
https://meowmin.taucity.xyz/terms
## Refund
https://meowmin.taucity.xyz/refund
```

---

## 10. Pre-Submission Checklist

- [ ] Create release signing keystore and configure `build.gradle.kts`
- [ ] Remove debug signing config for release builds
- [ ] Host privacy policy at meowmin.sh (surge index.html + privacy.html)
- [x] Create privacy policy pages (index.html + privacy.html)
- [x] Link privacy policy in app (About bottom sheet)
- [x] Add UGC report email (tauqeer1040@gmail.com)
- [x] Remove SCHEDULE_EXACT_ALARM from manifest
- [ ] Add UGC reporting mechanism (minimum: report email)
- [ ] Remove `SCHEDULE_EXACT_ALARM` commented permission from manifest
- [ ] Review Superwall dashboard pricing accuracy
- [ ] Build app bundle: `flutter build appbundle --release`
- [ ] Run pre-launch report in Play Console
- [ ] Test fresh install on Android 14+ device
- [ ] Test restore purchases flow
- [ ] Verify all screenshots match actual app UI
- [ ] Submit to Internal Testing track first (not production)

---

## Top Rejection Risks

1. **UGC without moderation** — highest risk. Add reporting capability.
2. **Privacy policy missing** — will block review. Create and host one.
3. **Debug signing in release build** — fixed before production submission, fine for internal testing.
4. **Scarcity tactics ("300 slots")** — may be flagged as deceptive. Consider removing slot numbers.
