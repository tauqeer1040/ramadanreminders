# Login Authentication Documentation

This document describes the authentication system implemented in this project for replicability.

## Authentication Method

The app uses **Firebase Authentication** with one supported methods:
1. **Google Sign-In** - OAuth-based authentication via Google

Additionally, **Anonymous/Guest accounts** are automatically created for unauthenticated users.

## Package Versions

### Flutter App (pubspec.yaml)

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.5.0 | Firebase initialization |
| `firebase_auth` | ^6.2.0 | Firebase Authentication |
| `firebase_ui_auth` | ^3.0.1 | Pre-built auth UI components |
| `firebase_ui_oauth_google` | ^2.0.1 | Google OAuth UI |
| `google_sign_in` | ^6.2.1 | Google Sign-In functionality |

### Backend (backend/package.json)

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase-admin` | ^13.7.0 | Firebase Admin SDK for backend operations |

## Setup Requirements

### 1. Firebase Console Configuration

Create a Firebase project and enable:
- **Authentication** > Sign-in methods > Google and Email/Password
- **Firestore Database** (for user data sync)

### 2. OAuth Client IDs

Obtain OAuth 2.0 client credentials from Google Cloud Console:

| Platform | Client ID |
|----------|-----------|
| Web | `470720192448-pi62jpdgfm3g1u7bml3adgomr63qsp0b.apps.googleusercontent.com` |
| iOS | `1059339297432-ebut10jtshmkgg4vf6a3frgioc5p60ob.apps.googleusercontent.com` |
| Android | `1059339297432-ms94q606vo3v8pa9rupob039l8ko4saf.apps.googleusercontent.com` |

### 3. Environment Variables (Backend)

Create `backend/.env`:
```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
```

### 4. Platform-Specific Configuration

**Android:** Place `google-services.json` in `android/app/`
**iOS:** Place `GoogleService-Info.plist` in `ios/Runner/`

## Login Flow - API Calls

### 1. Firebase Initialization

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 2. Configure Auth Providers

```dart
FirebaseUIAuth.configureProviders([
  EmailAuthProvider(),
  GoogleProvider(clientId: serverClientId),
]);
```

### 3. Google Sign-In (Client-Side)

```dart
static Future<UserCredential?> signInWithGoogle() async {
  final googleUser = await GoogleSignIn(
    serverClientId: serverClientId,
  ).signIn();

  if (googleUser != null) {
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }
  return null;
}
```

### 4. Email/Password Authentication

```dart
static Future<UserCredential?> continueWithEmail(String email, String password) async {
  final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
  
  if (methods.contains('password')) {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } else {
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
```

### 5. Anonymous Sign-In (Guest Mode)

```dart
await FirebaseAuth.instance.signInAnonymously();
```

### 6. User Data Sync (Post-Login)

After successful authentication, sync user data to Firestore:

```dart
static Future<void> syncUser(User user) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  await docRef.set({
    'uid': user.uid,
    'email': user.email,
    'displayName': user.displayName,
    'photoUrl': user.photoURL,
    'subscriptionTier': 'free',
    'stats': {...},
    'badges': [],
    'rewards': [],
    'journalCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
```

## Backend API Endpoints

After login, the frontend uses Firebase UID for authenticated API calls:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v2/user/upsert` | POST | Create/update user document |
| `/api/v2/user/:uid` | GET | Fetch user data |
| `/api/v2/user/:uid/journals` | GET | Fetch user's journals |
| `/api/v2/journals/sync` | POST | Sync journals with backend |

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/auth_service.dart` | Core authentication logic |
| `lib/services/user_service.dart` | User data synchronization |
| `lib/main.dart` | Firebase initialization |
| `lib/firebase_options.dart` | Platform-specific Firebase config |
| `lib/components/profilepage.dart` | Login UI (SignInScreen) |
| `backend/index.js` | Firebase Admin initialization |
| `backend/db2.js` | Backend API routes |

## Token Handling

- **Access/ID Tokens**: Managed automatically by Firebase SDK
- **User UID**: Primary identifier used across all authenticated operations
- **Token Refresh**: Handled by Firebase Auth automatically

## Sign Out

```dart
static Future<void> signOut() async {
  await GoogleSignIn().signOut();
  await FirebaseAuth.instance.signOut();
}
```
