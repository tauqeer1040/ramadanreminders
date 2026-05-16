# 📱 AI Quran Islam Diary — Full Technical Spec

---

## 🧠 PRODUCT OVERVIEW

Build a **Flutter-based mobile app** for daily spiritual growth, combining AI-powered journaling, dhikr tracking, Quran reading, and prayer time reminders.

The app must:
- Work **offline with local persistence** and sync when online
- Use **Firebase** for authentication, Firestore sync, and user management
- Provide a **premium native Android experience** with Material 3 Expressive design
- Deliver **smart notifications** for prayer times and daily spiritual reflections

---

## 🎯 CORE PRINCIPLES

- ⚡ Offline-first with cloud sync
- 🔐 Firebase Authentication with Google Sign-In + Anonymous
- 📱 Native Android feel with haptic feedback and Material 3 motion
- 🎨 Dynamic color support with deep teal fallback
- 🚀 Smooth UX (animations, haptics, sound)

---

## 🧱 SYSTEM ARCHITECTURE

### 🔄 High-Level Flow

1. User launches app → Anonymous auth or restored session
2. Local data loads (diary entries, dhikr counts, cached prayer times)
3. If online → Sync diary entries to Firestore, fetch latest prayer times
4. Background services → Prayer time notifications, daily reminders
5. Premium upgrade → Unlock advanced features via RevenueCat

---

## 📦 DATA MODELS

### Local Storage (SharedPreferences + Firestore)
- **DiaryEntry**: id, userId, date, content, tags, timestamps
- **DhikrItem**: id, name, targetCount, currentCount, isCompleted
- **TasbihSession**: session tracking for statistics
- **UserSettings**: notification prefs, prayer alert settings
- **PrayerTimes**: Cached daily prayer times by location

### Firestore Collections
```
users/{uid}
  - email, displayName, photoUrl, subscriptionTier, stats, badges, rewards, diaryCount

diaries/{uid}_entries/{entryId}
  - userId, date, content, tags, reflection, createdAt, updatedAt

user_stats/{uid}
  - totalDhikr, diaryCount, streakDays, lastActive

premium_features/{uid}
  - unlockedFeatures, expiresAt
```

---

## 🔐 AUTHENTICATION

### Firebase Authentication
- **Anonymous**: Auto-created on first launch
- **Google Sign-In**: OAuth-based, links to anonymous account
- **Email/Password**: Optional via `firebase_ui_auth`

---

## 🕌 PRAYER TIME SYSTEM

### Flow
1. **Get Location**: `Geolocator.getCurrentPosition()`
2. **Calculate Times**: `adhan` package with coordinates + date
3. **Cache**: Store in `SharedPreferences` for 24 hours
4. **Schedule Notifications**: `flutter_local_notifications` for each prayer
5. **Handle Permissions**: Request notification + location permissions

### Notification Types
- **Prayer Alerts**: Configurable alerts for each prayer time
- **Daily Reminder**: "Time to reflect on your day"
- **Dhikr Reminder**: "Complete your daily dhikr"

---

## 📖 QURAN READER

### Features
- Full Quran text with **Amiri font** for Arabic
- Chapter (Surah) list with search
- Bookmarking support
- Verse sharing

---

## 📝 DIARY SYSTEM

### Local + Cloud Sync
- **Local**: `SharedPreferences` for drafts and offline access
- **Cloud**: `cloud_firestore` for backup and cross-device sync
- **Auto-Sync**: `DiaryService.initAutoSync()` on app launch

### Features
- Create, edit, delete diary entries
- AI-powered insights based on your entries
- Tag entries (gratitude, prayer, growth, etc.)
- Reflection prompts
- Search and filter by date/tags

---

## 📿 TASBIH (DHIKR) TRACKER

### Features
- Digital tasbih counter with haptic feedback
- Multiple dhikr items
- Custom dhikr support
- Daily/weekly statistics with `fl_chart`
- Milestone celebrations with `confetti`

---

## 🏆 PREMIUM FEATURES

### RevenueCat Integration
- Unlock unlimited custom dhikr
- Advanced daily & weekly dhikr statistics
- Smart prayer-time reminders with custom sounds
- Cross-device sync & backup
- Ad-free & distraction-free

---

## 🎨 UI REQUIREMENTS

### Animations
- **Page Transitions**: `ZoomPageTransitionsBuilder`
- **Component Animations**: `Curves.easeInOutCubicEmphasized`
- **Dhikr Counter**: Scale animation on increment
- **Confetti**: `confetti` package for milestones

### Haptics
- **Navigation Tap**: `HapticFeedback.lightImpact()`
- **Dhikr Increment**: `HapticFeedback.mediumImpact()`
- **Premium Unlock**: `HapticFeedback.heavyImpact()`

---

## 🚀 FUTURE ROADMAP

- **Phase 1** (Current): Core features, AI insights, offline support, Firestore sync
- **Phase 2**: Premium features, RevenueCat integration, advanced statistics
- **Phase 3**: Social features (spiritual challenges, community reflections)
- **Phase 4**: Wear OS companion app, smart home integration
- **Phase 5**: Multi-language support (Arabic, Urdu, Indonesian, etc.)

---

## 🧪 DEVELOPMENT STRATEGY

### Phase 1: MVP
- Firebase Auth + Anonymous
- Diary CRUD + Firestore sync
- Basic dhikr counter
- Prayer times with notifications
- Quran reader with Amiri font

### Phase 2: Polish
- Premium features with RevenueCat
- Dhikr statistics with charts
- AI-powered spiritual coaching
- Performance optimization

### Phase 3: Growth
- Social features
- Multi-language support
- Wear OS app

---

## ✅ FINAL GOAL

A fast, peaceful, and premium daily companion app that helps users reflect, remember Allah, and stay connected to their faith every single day — with a beautiful native Android experience that feels like a spiritual home.
