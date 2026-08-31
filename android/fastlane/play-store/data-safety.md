# Meowmin AI Journal — Data Safety Answer Sheet
Package: `com.taucity.meowmin`  •  Category: Lifestyle
Use this sheet to fill the Play Console **App content → Data safety** form.

## 1. Does your app collect or share any required user data?
**Yes** — see the specific types below.

## 2. Data types collected (and where they go)
| Play category | Specific data | Collected by | Stored where | Transmitted? |
|---|---|---|---|---|
| App activity | User-generated content (journal entries, reflections, mood notes) | App (on-device) | **On device, encrypted at rest** (AES). Not uploaded to our servers. | No (stays local) |
| Diagnostics | Crash reports / diagnostics | Firebase Crashlytics | Firebase (Google) | Yes (to Google) |
| Device or other IDs | Instance ID / app-set ID | Firebase SDK | Firebase (Google) | Yes (to Google) |
| Account info | Email address (only if user signs in) | Firebase Auth | Firebase (Google) | Yes (to Google) |
| Financial info | Subscription / purchase status | RevenueCat SDK | RevenueCat | Yes (to RevenueCat) |

Notes:
- No precise location collected (no location permission requested).
- No contacts, microphone, camera, audio, or files collected (RECORD_AUDIO removed).
- No advertising SDKs; the app serves no ads.

## 3. Is this data shared with third parties?
**Yes** — with the following third parties, solely to operate the app:
- **Firebase / Google** (Crashlytics, Auth, Analytics) — diagnostics, device IDs, account email.
- **RevenueCat** — subscription/purchase status for entitlement unlocking.

We do not sell user data and do not share journal content with any third party.

## 4. Security practices
- Data encrypted **in transit** (HTTPS/TLS) for all network calls.
- Journal entries encrypted **at rest on the device**.
- Users can delete individual entries and their account inside the app; associated Firebase data is deleted on account deletion.

## 5. Data deletion / user controls
- In-app: Settings → Delete account removes the Firebase account and associated cloud data.
- Journal text is local-only; deleting the app or the account removes it.
- No server-side journal database is maintained by the developer.

## Console checkbox summary (recommended)
- "Data shared with third parties" → **Yes**
- "Collected data encrypted in transit" → **Yes**
- "Data can be deleted" → **Yes** (in-app account deletion)
- Optional: enable the "Data safety" spotlight only if you also show an in-app disclosure.
