# Security Audit - Ramadan Reflections App

## Critical

**`backend/index.js:195-237` — No authentication on journal sync endpoint**

The `/api/sync-journals` endpoint accepts `uid` and `journals` from the request body without verifying the caller's identity. Anyone can:
- Sync journals for ANY user by guessing or iterating UIDs
- Overwrite existing journal entries
- Inject malicious content (though `xss` sanitization helps)

```javascript
// Before — no auth check
app.post('/api/sync-journals', apiLimiter, async (req, res) => {
  const { uid, journals } = req.body;
  // ... processes for any uid
});

// After — verify Firebase ID token
app.post('/api/sync-journals', apiLimiter, async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  const idToken = authHeader.split('Bearer ')[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const verifiedUid = decodedToken.uid;
    
    // Ensure the token's UID matches the request body UID
    if (verifiedUid !== uid) {
      return res.status(403).json({ error: 'forbidden: uid mismatch' });
    }
    
    // Proceed with sync...
  } catch (error) {
    return res.status(401).json({ error: 'invalid token' });
  }
});
```

---

**`backend/index.js:240-261` — No authentication on get-insight endpoint**

The `/api/get-insight` endpoint fetches insights for any user without verifying the caller's identity.

```javascript
// Before — no auth check
app.get('/api/get-insight', apiLimiter, async (req, res) => {
  const { uid, date } = req.query;
  // ... fetches insight for any uid
});

// After — verify token and check ownership
app.get('/api/get-insight', apiLimiter, async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  try {
    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    
    // Verify user can only access their own insights
    if (decodedToken.uid !== req.query.uid) {
      return res.status(403).json({ error: 'forbidden' });
    }
    
    // Proceed with fetch...
  } catch (error) {
    return res.status(401).json({ error: 'invalid token' });
  }
});
```

---

**`lib/services/user_service.dart` — Client-side API calls may not send auth tokens**

The Flutter app needs to send Firebase ID tokens with backend API requests. If not implemented, the backend auth checks above won't work.

```dart
// User service should attach token to requests
static Future<Map<String, dynamic>> upsertUser(User user) async {
  final idToken = await user.getIdToken();
  
  final response = await http.post(
    Uri.parse('$backendUrl/api/v2/user/upsert'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({ /* user data */ }),
  );
  
  return jsonDecode(response.body);
}
```

---

## High

**`backend/index.js:23` — CORS allows all origins**

The backend uses `app.use(cors())` without restrictions, allowing any website to call the API.

```javascript
// Before — open CORS
app.use(cors());

// After — restrict to your domain
const corsOptions = {
  origin: [
    'https://ramadan-reflections.app',
    'http://localhost:3000', // for development
    'http://localhost:5000',
  ],
  credentials: true,
};
app.use(cors(corsOptions));
```

---

**`backend/index.js:27-33` — Rate limiting too restrictive**

Current limit: 10 requests per hour per IP. This may be too restrictive for active users syncing journals multiple times per day.

```javascript
// Recommended — differentiate limits by endpoint
const syncLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // 30 sync requests per 15 minutes
  message: { error: 'Too many sync requests, please try again later.' },
});

const insightLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // 10 insight requests per hour (AI generation is expensive)
});

app.post('/api/sync-journals', syncLimiter, ...);
app.get('/api/get-insight', insightLimiter, ...);
```

---

**No Firestore Security Rules defined**

The project uses Firebase Admin SDK on the backend, but client-side Firestore access (if any) needs security rules. The `docs/AUTHENTICATION.md` mentions `cloud_firestore`, so ensure:

```javascript
// firestore.rules
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /journals/{journalId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /tagIndex/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

---

**`backend/.env` — Sensitive credentials in environment**

While `.gitignore` should exclude `backend/.env`, verify these are not leaked:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `OPENROUTER_API_KEY`

**Recommendation**: Use a dedicated service account with minimal permissions, not the default admin credentials.

---

## Medium

**`backend/index.js:196` — No input validation on uid parameter**

The `uid` parameter isn't validated for format (Firebase UIDs have a specific format).

```javascript
// Add validation
function isValidFirebaseUid(uid) {
  // Firebase UIDs are typically 28 characters, alphanumeric
  return typeof uid === 'string' && /^[a-zA-Z0-9]{20,40}$/.test(uid);
}

if (!isValidFirebaseUid(uid)) {
  return res.status(400).json({ error: 'Invalid uid format' });
}
```

---

**`backend/index.js:207-209` — Limited XSS protection**

The `xss` package is used, but additional validation on journal structure is needed.

```javascript
// Validate journal structure
for (const journal of journals) {
  if (!journal.date || !journal.text) {
    continue; // Skip invalid entries
  }
  
  // Validate date format
  if (!/^\d{4}-\d{2}-\d{2}$/.test(journal.date)) {
    return res.status(400).json({ error: 'Invalid date format' });
  }
  
  // Validate text length
  if (typeof journal.text !== 'string' || journal.text.length > 3000) {
    return res.status(400).json({ error: 'Invalid text length' });
  }
  
  const cleanText = xss(journal.text).substring(0, 3000);
  // ... proceed with save
}
```

---

**No request logging/monitoring**

Add basic request logging to detect abuse patterns.

```javascript
const morgan = require('morgan');
app.use(morgan('combined')); // Logs all requests
```

---

**`lib/main.dart:33-38` — Anonymous auth auto-creation**

Automatically creating anonymous accounts is fine, but ensure proper cleanup of unused accounts to avoid Firebase project bloat.

**Recommendation**: Implement a cleanup function (Cloud Function) to delete anonymous accounts that haven't been active for 30+ days.

---

## Low

**Client-side API keys**

Check `pubspec.yaml` and `lib/` files for hardcoded API keys:
- RevenueCat API key (not currently in use, but plan for future)
- OpenRouter API key (correctly stored server-side only)
- Google OAuth client IDs (these are public by nature, not a vulnerability)

---

**No HTTPS enforcement**

Ensure the backend is only accessible via HTTPS in production. Firebase Hosting, Cloud Run, or similar services handle this automatically.

---

**Dependency vulnerabilities**

Regularly check for vulnerabilities in `backend/node_modules`:

```bash
cd backend
npm audit
npm audit fix
```

And for Flutter packages:

```bash
flutter pub outdated
flutter pub upgrade
```

---

## Summary

| Severity | Issue |
|----------|-------|
| **Critical** | No authentication on backend API endpoints |
| **Critical** | Client may not send Firebase ID tokens with requests |
| **High** | CORS allows all origins |
| **High** | Rate limiting too restrictive for sync endpoint |
| **High** | No Firestore security rules defined |
| **High** | Sensitive env vars need least-privilege access |
| **Medium** | No input validation on uid parameter |
| **Medium** | Limited XSS protection (needs more validation) |
| **Medium** | No request logging/monitoring |
| **Low** | Anonymous account cleanup needed |
| **Low** | No HTTPS enforcement check |
| **Low** | Dependency vulnerability checks |

---

## Immediate Actions

1. **Add Firebase ID token verification** to all backend endpoints (`/api/sync-journals`, `/api/get-insight`, `/api/random-ayah`)
2. **Update Flutter services** to send `Authorization: Bearer <idToken>` header with all API requests
3. **Restrict CORS** to allowed origins only
4. **Define Firestore security rules** if using client-side Firestore access
5. **Adjust rate limits** to be more permissive for sync, stricter for AI generation
6. **Add input validation** for all parameters (uid, date, journal structure)
7. **Set up request logging** to monitor for abuse

---

## Testing Security

After implementing fixes, test with:

```bash
# Test unauthenticated request (should fail)
curl -X POST http://localhost:3000/api/sync-journals \
  -H "Content-Type: application/json" \
  -d '{"uid":"test","journals":[]}'
# Expected: 401 Unauthorized

# Test authenticated request (should succeed)
curl -X POST http://localhost:3000/api/sync-journals \
  -H "Authorization: Bearer <valid-firebase-id-token>" \
  -H "Content-Type: application/json" \
  -d '{"uid":"<same-as-token>","journals":[]}'
# Expected: 200 OK

# Test UID mismatch (should fail)
curl -X POST http://localhost:3000/api/sync-journals \
  -H "Authorization: Bearer <valid-firebase-id-token>" \
  -H "Content-Type: application/json" \
  -d '{"uid":"different-uid","journals":[]}'
# Expected: 403 Forbidden
```
