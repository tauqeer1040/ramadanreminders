# Screenshot → Story Share flow

> 2026-09-11 additions at bottom: native Kotlin reminder chain, moment
> paywalls, install-scoped trial clock.

---

Reference doc for the screenshot-detection / insight story-sharing feature
(QuranPage). Verified 2026-09-10 against package source + app code.
`flutter analyze` clean on all touched files.

## Flow overview

```
User screenshots phone
  └─ flutter_screenshot_detect 0.1.7 (pubspec: ^0.1.7)
       EventChannel 'com.ss.detect/events' (package-internal, don't touch)
  └─ StoryShareService.listenForScreenshots()   lib/services/story_share_service.dart
       wraps detector stream; also owns Instagram/WhatsApp/system share
  └─ QuranPage._onDeviceScreenshot()            lib/components/quranpage.dart
       500ms debounce (OS finishes writing file) → _offerShare('screenshot')
  └─ _offerShare(source)  — gates + once-per-card throttle + capture
  └─ _captureTopCard()    — ScreenshotController.capture(pixelRatio: dpr)
       writes PNG to getTemporaryDirectory() → 'insight_<ms>.png'
  └─ showShareInsightSheet()                    lib/components/widgets/share_insight_sheet.dart
       Instagram Story / WhatsApp Status / 'share' buttons
       ('share' = system share sheet; dark-purple DuoButton,
       black text, Icons.ios_share_rounded)
  └─ StoryShareService.shareInstagramStory / shareWhatsappStatus
       MethodChannel 'com.taucity.meowmin/share' → MainActivity.kt
       Android: Instagram ADD_TO_STORY intent (fallback: targeted ACTION_SEND),
       WhatsApp: targeted ACTION_SEND (picker includes My Status)
       fallback chain: direct target fails → system share sheet (share_plus)
```

Second trigger: double-tap "like" on a card calls `_offerShare('like')`
(quranpage ~line 1400); falls back to `_scheduleDelightSheet()` when share
wasn't offered.

## File map

| File | Role |
|---|---|
| `pubspec.yaml` | `flutter_screenshot_detect: ^0.1.7`, `screenshot: ^3.0.0`, `share_plus`, `path_provider` |
| `lib/services/story_share_service.dart` | Detection stream wrapper + share methods + `stopListeningForScreenshots()` |
| `lib/components/quranpage.dart` | Detection listener (initState), gates, capture, `_offerShare` throttle |
| `lib/components/widgets/share_insight_sheet.dart` | Bottom-sheet UI + analytics (`share_sheet_shown`, `share_sheet_action`) |
| `android/.../MainActivity.kt` | MethodChannel `com.taucity.meowmin/share` handlers (story intents) |
| `android/app/src/main/res/xml/filepaths.xml` | FileProvider paths: `<cache-path>` + `<external-cache-path>` cover the temp PNGs — do not delete |
| `android/.../AndroidManifest.xml` | `<queries>` for `com.instagram.android` / `com.whatsapp` (Android 11+ package visibility) |

## Package internals (flutter_screenshot_detect 0.1.7) — verified from source

- Dart API: `FlutterScreenshotDetect().onScreenshot` → `Stream<FlutterScreenshotEvent>` (`method`, `timestamp` µs, `path?`). Code in `story_share_service.dart` matches.
- **Detection is app-wide on all platforms.** Fires regardless of which tab/screen is visible, and on Android <14 the MediaStore observer also fires for *other apps'* images while our app is backgrounded.
- Native Android: Android 14+ (UPSIDE_DOWN_CAKE) uses `Activity.ScreenCaptureCallback`; older uses a `MediaStore` ContentObserver (no permissions needed from us).
- iOS: `UIApplicationUserDidTakeScreenshotNotification`.
- Known package quirks (their bug, we compensate in Dart): observer leaks in `onCancel` via `!!`, `isScreenshotPath` is a trivial `contains()` check, `dispose()` only nulls the stream (Dart-side harmless).

## Fixes applied 2026-09-10 (quranpage.dart)

1. **Transparent captures.** `AppBackground` lived in `main_screen.dart` *outside* the `Screenshot` subtree and the Scaffold was `Colors.transparent` → shared PNGs had alpha holes. Fixed by restructuring:
   `Scaffold → Screenshot → AppBackground → SafeArea → Column`. The whole branded page (background + "meowmin" logo top bar + cards) is inside the capture — intentional for free marketing when users post stories.
2. **Blurry captures.** `capture()` defaulted to logical resolution (~390px wide). Now `pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context).clamp(1.0, 3.0)`.
3. **Sheet fired on other tabs / backgrounded.** Detection is app-wide and all 4 tabs share one route (`ModalRoute.isCurrent` can't distinguish). Added:
   - `WidgetsBindingObserver` → ignore events unless `AppLifecycleState.resumed`.
   - `_isPageVisible()` → checks this page's RenderBox is ≥50% on screen (hidden PageView tabs sit one screen-width to the side).
4. **Throttle key burned on suppressed attempts.** `_shareOfferedCardKeys` (once per `source:cardId:deckId` per page session) was recorded *before* the capture attempt; a wrong-tab/failed attempt permanently consumed it. Now only added right before the sheet shows.

## Remaining platform limitations (accepted)

- Android <14 + app backgrounded + screenshot of another app: the MediaStore observer fires, but lifecycle gate blocks it. However if the app is foregrounded on insights tab and a screenshot is taken of a *different app* via split-screen, we can't tell (rare; sheet offer is harmless).
- Sheet only auto-offers once per card per source per session; like-trigger offers second source for the same card.
- iOS has no equivalent of Android 14's "app took the screenshot" callback — iOS users screenshotting other apps while we're foregrounded would trigger it (mitigated by `resumed` check only if we're actually foreground).

## Device testing checklist

1. Android 14+: screenshot insights tab → sheet within ~0.5–1s; capture shows bg + logo + cards, no transparency.
2. Android <14: same via MediaStore observer (test both photo of screen via camera and system screenshot).
3. Background the app, screenshot home screen, resume → **no** sheet.
4. Switch to home/shop/profile tab, screenshot, switch back → sheet appears only if screenshot taken while insights tab visible.
5. With Instagram uninstalled: Instagram button → falls back to system share sheet.
6. Double-tap like → share sheet (not stacked with delight sheet).
7. Same card screenshot twice → second screenshot offers nothing (once per card per source).

---

## 2026-09-11: Native reminder chain + moment paywalls

### Native Kotlin notifications (replaces flutter_local_notifications on Android)
- **Extracted into the reusable plugin `packages/meowmin_notifications`** (path dep;
  see its README for host-app setup). App no longer contains notification Kotlin.
  - Plugin: `MeowminNotificationsPlugin` (MethodChannel `com.meowmin.notifications/reminders`)
    → `MeowminReminders` object + `ReminderReceiver` (self-re-arming) +
    `ReminderBootReceiver` (BOOT_COMPLETED / MY_PACKAGE_REPLACED re-seed).
  - Dart API: `MeowminNotifications.schedule(config) / cancel() / fireTestSequence() /
    showNow(isMorning:)`.
  - Chain: exact-when-allowed alarms (`setExactAndAllowWhileIdle`; inexact fallback
    without special access) → receiver shows + re-arms tomorrow from native prefs.
    Flutter-independent (Monito pattern). Copy stored in native prefs, so the
    receiver renders with the engine dead.
  - Branding resolved per-app by resource name: `ic_notification` (white silhouette
    small icon), `notification_face` (color large icon), optional
    `meowmin_notification_channel_name/description` strings. Host app declares the
    permissions (POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM).
  - Package manifest gotcha fixed: `<receiver>` entries MUST be inside `<application>`
    or AAPT fails with "unexpected element <receiver> found in <manifest>".
- Copy (configured in `NotificationService.scheduleNativeReminders`): heading = cat
  name from onboarding (`onboarding_catName`, fallback "Meowmin"); 8am body
  "Read your insights for the day"; 10pm body "It's time to write your diary, {name}".
- Icons in this app: small = `drawable-*/ic_notification.png` (white face.webp
  silhouette, generated via PIL — regenerate if mascot changes); large =
  `notification_face.png` (color face).
- Verified on device with the package chain: 4/4 test notifications delivered;
  `dumpsys alarm` shows `window=0 exactAllowReason=permission` (true exact) at
  08:00 and 22:00.
- `NotificationService.scheduleDailyNotifications()` delegates to native on Android;
  flutter_local_notifications remains the iOS/web path. Debug card has "Fire Day
  Notif" / "Fire Night Notif" buttons (`showNow` through the package).

### Moment paywalls (free users)
- `MomentPaywallService` (`lib/services/moment_paywall_service.dart`): frequency-capped
  (30min/moment) paywall after `journal_saved` (editor back button) and `deck_revealed`
  (last scratch card). Dismissable while 3-day trial active; hard gate after.
- `LocalTrialService` rewritten: trial clock keyed to install id = ANDROID_ID (SSAID),
  stable across reinstalls. Legacy device-global/per-uid clocks adopted once.
- `device_info_plus` added for SSAID.
- Manage account: free users' two email buttons now open the paywall ("Get Max");
  pro users keep Customer Center.
