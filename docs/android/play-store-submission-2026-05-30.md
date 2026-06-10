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
| Superwall IAP subscription | **Medium** | $1 trial → $9/mo or $59/yr. Paywall on onboarding. |
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
| Cloud Firestore | User profile, journal data | User data storage | No |
| Superwall | User ID, purchase events | Subscription management | No (Superwall processes payments) |
| Google Sign-In | Name, email, profile photo (if used) | Social login | No |
| Geolocator | Precise location | Prayer time calculation | No |
| flutter_local_notifications | None | Local notifications | No |
| audioplayers | None | Audio playback | No |
| http | None | Backend API calls | No |
| shared_preferences | None | Local cache | No |

### Privacy Policy Must Cover
- What data is collected (journal entries, location for prayer times, email if signed in)
- How AI (OpenRouter) processes journal text to generate insights
- Third parties: OpenRouter, Superwall (payment processing), Google (Firebase)
- Data deletion: account deletion via Profile → Delete Account
- Contact email

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

## 6. Monetization & Superwall IAP

| Requirement | Status | Notes |
|------------|--------|-------|
| Price shown before purchase | ✅ | Superwall handles this server-side |
| Clear subscription terms | ⚠️ | Verify Superwall dashboard has correct pricing: $1 trial → $9/mo or $59/yr |
| Restore purchases | ⚠️ | Superwall handles this, verify the restore button is accessible |
| Cancel path | ✅ | Play Store manages subscription cancellation |
| Trial auto-renew warning | ✅ | Superwall handles this |
| Scarcity tactics ("300 slots") | ⚠️ | "Limited to 300 members" and slot counter may be flagged as deceptive urgency by reviewers. Consider softening or removing the slot number. |

### Superwall Configuration
- **Placement:** `StartTrial`
- **Identify:** `Superwall.shared.identify(user.uid)` called before placement
- **PK:** `pk_H_7a9WkW5nHJqKZPKsub1` (hardcoded in `main.dart`)

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
Email: reviewer@meowmin.app (create a test account)
Password: (provide in Play Console)

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

3. Subscription
   - $1 for 3-day trial, then $9/month or $59/year
   - Subscription unlocks unlimited journal entries + AI insights
   - Paywall appears during onboarding after free trial entries
   - Guest users get 3 free journal entries before paywall

## Special Instructions
- First launch shows onboarding flow with paywall
- AI insights may take 30–60 seconds after journaling
- Backend is at: libsql://meowmin-tauqeer.aws-ap-south-1.turso.io
- Journals sync when app opens or at midnight

## Privacy Policy
https://meowmin.sh/privacy.html
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
