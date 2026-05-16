# Streaks Card & Widget — AI Quran Islam Diary

How the streak system works end-to-end in the AI Quran Islam Diary: calculation, UI, persistence, homescreen widgets, and achievement notifications.

---

## Overview

The streak system tracks your consistent engagement with spiritual reflection.

| Streak Type | Scope | Persistence | Resets |
|---|---|---|---|
| **Daily reflection streak** | App-wide | `SharedPreferences` + Firestore sync | Resets to 1 when >1 day gap in activity |

**Cardinal rule**: the daily streak is **never 0**. It defaults to 1 and represents your commitment to daily spiritual growth.

---

## Architecture

```
main.dart (app resume)
  └─ StreakService.recordActivity()
       ├─ SharedPreferences (local source of truth)
       └─ Firestore (sync if logged in)

journal_editor_screen.dart (entry saved)
  ├─ StreakService.incrementStreak()
  └─ JournalService.saveEntry()
       ├─ SharedPreferences
       ├─ WidgetService → Android HomeWidget (native Kotlin)
       └─ Firestore sync
```

---

## Data Model

### `StreakData`

```dart
class StreakData {
  final int currentStreak;
  final DateTime lastActivityDate;
}
```

---

## Streak Calculation

### Daily reflection streak

```
today = DateTime.now() stripped of time
last  = prefs.getString("last_activity_date")

if last == null               → streak = 1
if last == today              → no change (already tracked)
if last == yesterday          → streak++
else (gap > 1 day)            → streak = 1

Save streak + today's date to prefs.
If logged in → sync to Firestore.
```

---

## StreakGraph Widget

A `StatefulWidget` accepting `streak` (int) and `size` (double, default 280).

### Layout

```
┌──────────────────────────────┐
│          🔥 (Lottie)         │  ← "Streak Fire.json", fallback fire icon
│                              │
│          42                  │  ← widget.size * 0.25 font, white weight 900
│      day streak!             │
│                              │
│  ┌────────────────────────┐  │
│  │  Mo  Tu  We  Th  Fr  Sa│  │  ← 7-day scrollable graph
│  │  🔥  🔥  🔥  ✨  🔥  ? │  │     centered on current streak
│  │  (3) (4) (5) (6) (7) (8)│  │     startDay = (streak - 3).clamp(1)
│  └────────────────────────┘  │
│                              │
└──────────────────────────────┘
```

---

## Persistence & Sync

### Save flow

```
recordActivity()
  ├─ SharedPreferences: currentStreak, lastActivityDate
  ├─ WidgetService.updateWidget()  → updates homescreen widget
  └─ Firestore: update user stats
```

---

## Android Homescreen Widget

### Streak Widget

**Provider**: `StreakWidgetProvider.kt`
**Layout**: `widget_streak.xml` — displays your current spiritual streak.

Reads from shared preferences:

```kotlin
val streak = widgetData.getString("streak", "0")
```

---

## Achievement Notifications

| Milestone | Title |
|---|---|
| 7 | One week of reflection! 🌟 |
| 30 | 30 days of growth! 🔥 |
| 100 | Spiritual champion! 🏆 |

---

## Styling (from `design.md`)

| Token | Value | Usage |
|---|---|---|
| `primary` | `#006A60` | Deep Teal — Branding, primary actions |
| `gold` | `#D4AF37` | Premium Gold — Achievement highlights |

---

## Key Files Reference

| File | Purpose |
|---|---|
| `lib/services/streak_service.dart` | Main calculation, persistence, and logic |
| `lib/services/widget_service.dart` | Flutter ↔ Android widget bridge |
| `lib/services/notification_service.dart` | Achievement milestone notifications |
| `lib/main.dart` | `recordActivity()` on app start |
| `lib/design.md` | Design guidelines and theme tokens |
| `assets/photos/streak.png` | Streak image asset |
