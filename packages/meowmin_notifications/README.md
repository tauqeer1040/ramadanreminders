# meowmin_notifications

Reusable Flutter plugin: **native Android daily-reminder chain** that keeps
firing even when the app is killed, the device reboots, or the Flutter engine
never starts — the pattern abandoned apps use to keep notifications working
for years.

## How it works

```
Dart (app launch)          AlarmManager              BroadcastReceiver
─────────────────          ────────────              ──────────────────
MeowminNotifications ──▶ exact-when-allowed ──▶  ReminderReceiver
   .schedule(config)      setExactAndAllow…       1. shows notification
                                                   2. re-arms itself for
                                                      tomorrow (self-sustaining
                                                      chain, no app needed)
ReminderBootReceiver ◀── BOOT_COMPLETED / MY_PACKAGE_REPLACED
   (re-seeds both alarms from native prefs)
```

Copy, hours, and channel config are stored in **native SharedPreferences**,
so the receiver never needs the Flutter engine.

## Host-app setup (2 steps)

**1. Dependency** (`pubspec.yaml`):

```yaml
dependencies:
  meowmin_notifications:
    path: ../packages/meowmin_notifications
```

**2. Branding resources** in the host app's `android/app/src/main/res`:

| Resource | Required | Notes |
|---|---|---|
| `drawable-*/ic_notification.png` | yes | **White silhouette** (alpha-only art) — the status-bar small icon is tinted by the system. Full-color art renders as a filled circle/box. |
| `drawable-*/notification_face.png` | no | Full-color brand mark shown as the large icon next to the notification. Never tinted; transparency preserved. |
| `res/values/meowmin_notifications.xml` | no | Channel name/description overrides: `<string name="meowmin_notification_channel_name">…</string>`, `…channel_description`. |

AndroidManifest permissions are the host app's responsibility (see
Permissions below).

## Usage

```dart
import 'package:meowmin_notifications/meowmin_notifications.dart';

// On every app launch (cheap; converges to one alarm chain per reminder):
await MeowminNotifications.schedule(
  const MeowminReminderConfig(
    titleMorning: 'Meowmin',
    bodyMorning: 'Read your insights for the day',
    titleNight: 'Meowmin',
    bodyNight: "It's time to write your diary, Sam",
    morningHour: 8,   // 8:00 AM
    nightHour: 22,    // 10:00 PM
  ),
);

// Personalize copy later (e.g. after onboarding) — just call schedule again.
// Teardown (user turns reminders off):
await MeowminNotifications.cancel();
```

## Permissions (host app AndroidManifest)

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<!-- Exact alarms: user-grantable "Alarms & reminders" special access.
     Without it the plugin falls back to inexact alarms automatically. -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

The plugin **declares the receivers** (merged from its own manifest) but not
the permissions — the host decides its permission policy.

## Debug helpers

```dart
// Immediate + 3 alarms at +10/20/30s: proves the whole chain without
// waiting for a wall-clock slot.
await MeowminNotifications.fireTestSequence();

// Preview the stored morning/night notification right now.
await MeowminNotifications.showNow(isMorning: true);
```

## Platform notes

* **Android only.** All Dart methods no-op (return `false`) elsewhere; pair
  with `flutter_local_notifications` for iOS/web in host apps.
* Exact vs inexact is chosen at schedule time via
  `AlarmManager.canScheduleExactAlarms()` — no crash on Android 12+ without
  the special access, just inexact delivery (may batch up to ~1h on OEMs).
* Deep links (optional): declare an activity named
  `<your.package>.NotificationEntryActivity` and pass payloads via
  `show(...)` extension points — see `MeowminReminders.contentIntent`.
