# AI Quran Islam Diary - App Logic Spec

## Core Concept
A premium daily spiritual growth companion app for building a closer connection with Allah through AI-powered journaling (Diary), dhikr tracking, Quran reading, and prayer time reminders. Users earn streaks, maintain daily reflections, and receive personalized spiritual insights.

## Data Models

### DiaryEntry
```dart
class DiaryEntry {
  String id;           // unique identifier (Firestore doc ID)
  String userId;         // Firebase UID
  DateTime date;         // entry date
  String content;        // diary text
  String? reflection;   // optional reflection prompt response
  List<String> tags;    // e.g., ["gratitude", "prayer", "growth"]
  DateTime createdAt;
  DateTime updatedAt;
}
```

### DhikrItem
```dart
class DhikrItem {
  String id;           // unique identifier
  String name;          // e.g., "SubhanAllah", "Alhamdulillah"
  int targetCount;      // target repetitions (e.g., 33, 99, 100)
  int currentCount;     // current progress
  String? customText;   // user-defined dhikr text
  bool isCompleted;     // reached target
  DateTime lastUpdated;
}
```

### TasbihSession
```dart
class TasbihSession {
  String id;
  String userId;
  List<DhikrItem> dhikrList;      // active dhikr items
  int totalCount;                   // total dhikr count across session
  Map<String, int> dhikrStats;    // {"SubhanAllah": 33, "Alhamdulillah": 33}
  DateTime startTime;
  DateTime? endTime;
  bool isActive;
}
```

### PrayerTimes
```dart
class PrayerTimes {
  DateTime fajr;
  DateTime sunrise;
  DateTime dhuhr;
  DateTime asr;
  DateTime maghrib;
  DateTime isha;
  String location;      // city name
  double latitude;
  double longitude;
  DateTime date;
}
```

### AuthUser
```dart
class AuthUser {
  String uid;           // Firebase UID
  String? googleId;     // Google OAuth ID (set after sign-in)
  String? email;
  String? displayName;
  String? photoUrl;
  bool isAnonymous;      // true if not signed in
  String subscriptionTier; // "free" | "premium"
  int diaryCount;
  Map<String, dynamic> stats;
  List<String> badges;
  List<String> rewards;
}
```

## Auth Flow

1. **Anonymous Session**: App creates Firebase anonymous auth on first launch
2. **Google Sign-In**: Links Google account to anonymous session
3. **Email/Password**: Optional sign-up method via `firebase_ui_auth`
4. **Sign-Out**: Clears Google, creates new anonymous session
5. **Premium Upgrade**: Via RevenueCat integration

## Core Services

### DiaryService
- `createEntry(content, tags)` - Create new diary entry
- `updateEntry(id, content, tags)` - Edit existing entry
- `deleteEntry(id)` - Remove entry
- `syncToFirestore()` - Auto-sync diary entries to backend
- `getEntries(dateRange)` - Fetch entries by date

### DhikrService
- `loadDhikrList()` - Load user's dhikr items
- `incrementDhikr(id)` - Increment dhikr count with haptic feedback
- `resetDhikr(id)` - Reset count to zero
- `addCustomDhikr(name, target)` - Add user-defined dhikr
- `getStatistics()` - Return daily/weekly dhikr stats for charts

### PrayerTimeService
- `getCurrentLocation()` - Get device GPS coordinates
- `fetchPrayerTimes(date, lat, lng)` - Calculate daily prayer times
- `scheduleNotifications()` - Set up local notifications for each prayer

### NotificationService
- `init()` - Initialize notifications
- `requestPermissions()` - Request notification permissions
- `scheduleDailyNotifications()` - Schedule prayer time alerts
- `scheduleDhikrReminder()` - Remind users to complete daily dhikr

### AuthService
- `signInWithGoogle()` - Google OAuth flow
- `signInAnonymously()` - Guest mode
- `syncUser(user)` - Sync user data to Firestore
- `signOut()` - Sign out and create new anonymous session

## Screens

### Homepage (Home Screen)
- Greeting header with dynamic date (Hijri + Gregorian)
- **Diary Section**: Latest entries carousel, quick add button
- **Dhikr Summary**: Today's dhikr count, quick access to Tasbih
- **Prayer Times Card**: Next prayer countdown, all prayer times expandable
- **Reflect Card**: Daily reflection prompt to get closer to Allah
- **Action Prompt**: Contextual suggestions (e.g., "Write in diary", "Complete dhikr")

### QuranPage
- Full Quran text with beautiful Amiri font
- Chapter (Surah) list with search
- Bookmarking support
- Verse sharing functionality

### TasbihScreen
- Digital tasbih counter with haptic feedback
- Multiple dhikr items in a list
- Circular progress indicators for each dhikr
- Statistics view (daily/weekly charts)

### ProfilePage (Bottom Sheet)
- User profile display (photo, name, email)
- Diary count, dhikr stats summary
- Sign in/out buttons
- Premium upgrade CTA

## Navigation
- **Bottom Navigation**: 4 tabs (Home, Quran, Tasbih, Profile)
- **Floating Action Button**: Quick diary entry
- **Profile**: Accessible from the bottom navigation or homepage avatar

## Offline Support
- Diary entries stored locally via `shared_preferences`
- Dhikr counts persisted locally
- Prayer times cached for 24 hours
- Auto-sync when online via `DiaryService.initAutoSync()`

## Premium Features
- Unlimited custom dhikr items
- Advanced daily & weekly dhikr statistics with charts
- Smart prayer-time reminders with custom sounds
- Cross-device sync & backup via Firestore
- Ad-free & distraction-free experience

## Build Config
- Package: `com.islam.diary.ai`
- Permissions: Location (for prayer times), Notifications
