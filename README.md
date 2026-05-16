# AI Quran Islam Diary

A premium native Android app for daily spiritual growth, combining AI-powered journaling, dhikr tracking, Quran reading, and prayer time reminders — built with Flutter and Material 3 Expressive design.

## Features

- **AI-Powered Diary:** Write daily reflections and receive personalized Islamic insights with Firestore backup.
- **Tasbih Counter:** Track dhikr with custom lists, detailed statistics, and achievement milestones.
- **Quran Reader:** Read the Holy Quran with beautiful Amiri font support and bookmarking.
- **Prayer Times:** Accurate daily prayer times based on your location with smart notifications.
- **Closer to Allah:** Designed to help you build a consistent spiritual habit throughout the year, including special support for Ramadan.
- **Premium Experience:** Unlock unlimited dhikr, advanced statistics, and cross-device sync.
- **Dynamic Theme:** Adapts to your system's dynamic color with a deep teal fallback and smooth Material 3 motion.

## Getting Started

### Prerequisites
- Flutter SDK ^3.9.2
- Firebase project with Authentication and Firestore enabled
- Google Sign-In OAuth client IDs for Android/iOS/Web

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ramadan_app.git
   cd ramadan_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Place `google-services.json` in `android/app/`
   - Place `GoogleService-Info.plist` in `ios/Runner/`
   - Update `lib/firebase_options.dart` with your project configuration

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── components/          # UI components (homepage, diary, tasbih, quran)
├── core/              # Constants and core utilities
├── features/          # Feature modules (tasbih)
├── models/            # Data models
├── services/          # Business logic (auth, diary, dhikr, prayer times)
└── main.dart          # App entry point
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | User authentication |
| `cloud_firestore` | Data sync and user data |
| `google_sign_in` | Google OAuth login |
| `dynamic_color` | Material 3 dynamic color support |
| `google_fonts` | Typography (Inter and Amiri) |
| `adhan` | Prayer time calculations |
| `geolocator` | Device location |
| `flutter_local_notifications` | Smart reminders |
| `confetti` | Milestone celebrations |

## Documentation

- [Design System](design.md) — Material 3 Expressive guidelines
- [App Specification](SPEC.md) — Data models and logic
- [Technical Plan](plan.md) — Architecture and roadmap
- [Onboarding Flow](onboarding.md) — The 20-screen user journey
- [Security Audit](SECURITY_AUDIT.md) — Security best practices

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is private and proprietary. All rights reserved.
