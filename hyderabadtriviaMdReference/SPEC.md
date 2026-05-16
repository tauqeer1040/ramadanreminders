# Hyderabad Trivia - App Logic Spec

## Core Concept
Quiz app about Hyderabad landmarks. Users earn score, maintain streak, compete on leaderboard.

## Data Model

### QuizQuestion
```dart
class QuizQuestion {
  String id;        // unique identifier
  String imageUrl;   // asset path
  List<String> options;  // 4 choices
  String correctAnswer;
  String trivia;     // fun fact shown after answering
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
  bool isAnonymous;     // true if not signed in
}
```

### QuizProgress
```dart
class QuizProgress {
  int score;           // current score
  int bestScore;       // all-time high
  int streak;          // consecutive correct answers
  Set<String> completedCards;  // question IDs answered correctly
}
```

## Auth Flow

1. **Anonymous Session**: App creates Firebase anonymous auth on first launch
2. **Google Sign-In**: Links Google account to anonymous session
   - Requires SHA-1 fingerprint in Firebase Console
   - Requires Anonymous provider enabled in Firebase Console
3. **Sign-Out**: Clears Google, creates new anonymous session

## Scoring

- Correct answer: **+10 points**
- Wrong answer: **-8 points** (score floor is 0)
- Score persists locally via SharedPreferences
- When all questions completed: reset question pool, keep score

## Session Tracking

- Backend records: userId, platform, elapsed time, cards viewed, score
- Session starts on app launch (after auth)
- Session ends on app background/exit

## Screens

### QuizScreen (Home)
- Vertical carousel of questions
- Top bar: logo, leaderboard button, score widget
- Question card: image + "Where is this?" + 4 option buttons
- After answer: trivia overlay slides up
- Auto-advances after 6 seconds or tap "Next card"

### LeaderboardScreen
- Shows top users by score
- Displays: rank, name, score, streak

### SettingsScreen (Profile tab)
- User profile display
- Sign in/out buttons
- Auth progress debug card (commented out)

## Key Services

- **FirebaseAuthService**: Firebase auth operations
- **AuthStore**: Local persistence of AuthUser
- **BackendApi**: Server sync (start/update/end session, leaderboard)
- **QuizProgressStore**: Local persistence of quiz progress
- **PostHogService**: Analytics (capture events, identify users)

## Build Config

- Package: `com.hyderabadtrivia`
- Debug keystore: `~/.android/hyderabadtrivia_debug.keystore`
- SHA-1 fingerprint: Add to Firebase Console for Google Sign-In
