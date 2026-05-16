# Security Audit - Hyderabad Trivia App

## Critical

**`lib/services/revenuecat_service.dart:22` — RevenueCat API key hardcoded in client bundle**

The API key `test_wykJFUSuejRrPHlBujocRNrJTdO` is hardcoded in the Flutter app. This key is visible in the source code and can be extracted via reverse engineering. Anyone who extracts this key could:
- Access your RevenueCat dashboard
- View/cancel all subscriptions
- Issue fraudulent refunds

```dart
// Before — hardcoded in client
static const String _apiKey = 'test_wykJFUSuejRrPHlBujocRNrJTdO';

// After — proxy billing through your backend, or use environment variables via platform config
// RevenueCat recommends: call purchases through your server, not client
```

---

**`server/src/index.js:31-65` — No authentication on ANY backend endpoint**

NONE of the API endpoints verify the caller's identity. Anyone can:
- Create/fake user accounts
- Set their subscription to "premium" 
- Submit fake scores/leaderboard entries
- Send progress for ANY user

```javascript
// Before — no auth check
app.post('/api/users/upsert', async (req, res, next) => {
  const { uid, googleId, email, displayName, photoUrl, isAnonymous } = req.body;
  // ... accepts any data from anyone
});

// After — validate Firebase token server-side
app.post('/api/users/upsert', async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  // verification logic here...
});
```

---

**`server/src/index.js:51-65` — Client-controlled subscription status**

An attacker can set their subscription to "premium" or any value by sending:
```json
POST /api/users/123/subscription
{ "subscriptionStatus": "premium" }
```

The server blindly accepts the status from the client without verifying with RevenueCat.

```javascript
// Before
app.post('/api/users/:userId/subscription', async (req, res, next) => {
  const { subscriptionStatus } = req.body; // from client!
  const user = await updateSubscriptionStatus(req.params.userId, subscriptionStatus);
});

// After — verify via RevenueCat webhooks, never trust client
app.post('/webhooks/revenuecat', async (req, res, next) => {
  // Verify webhook signature first
  const signature = req.headers['x-revenuecat-signature'];
  if (!verifyRevenueCatSignature(signature, req.body)) {
    return res.status(401).json({ error: 'invalid signature' });
  }
  // Only process events from RevenueCat
});
```

---

## High

**`server/src/index.js:81-98` — Client-controlled progress data**

Users can submit arbitrary scores, bestScores, streaks, and completedCards:

```javascript
// Before — accepts all from client
app.post('/api/users/:userId/progress', async (req, res, next) => {
  const { score, bestScore, streak, completedCards } = req.body;
  // user can set anything: score: 999999999
});

// After — validate and enforce limits server-side
app.post('/api/users/:userId/progress', async (req, res, next) => {
  const score = Math.min(Number(req.body.score) || 0, MAX_POSSIBLE_SCORE);
  const bestScore = Math.min(Number(req.body.bestScore) || 0, MAX_POSSIBLE_SCORE);
  // Don't trust submitted completedCards; recalculate from game logic
});
```

---

**`server/src/index.js:115-131` — No session ownership verification**

Anyone can update ANY session's progress by guessing a sessionId:

```javascript
// Before
app.post('/api/sessions/:sessionId/progress', async (req, res, next) => {
  // no check that caller owns this sessionId
});

// After — require userId token and verify session ownership
app.post('/api/sessions/:sessionId/progress', async (req, res, next) => {
  const tokenUserId = verifyToken(req.headers.authorization);
  const session = await getSession(req.params.sessionId);
  if (session.user_id !== tokenUserId) {
    return res.status(403).json({ error: 'forbidden' });
  }
});
```

---

**Leaderboard accepts client-provided `bestScore`** — `server/src/repository.js`

The leaderboard pulls score directly from the users table which is client-controlled:

```javascript
// Before — pulls best_score from user-submitted data
const leaders = await db.execute({
  sql: `SELECT uid, display_name, photo_url, best_score, subscription_status
    FROM users ...` // client-supplied!
});

// After — track scores server-side only, never from client
// bestScore should be calculated from server-tracked game completions
```

---

## Medium

**`server/src/index.js` — No rate limiting on any endpoint**

Endpoints like `/api/users/upsert`, `/api/sessions/start`, and `/api/leaderboard` have no rate limits. Attackers can:
- Spam create users
- Flood the leaderboard
- Exhaust server resources

```javascript
// Add rate limiting (e.g., express-rate-limit)
import rateLimit from 'express-rate-limit';
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per window
});
app.use('/api/', apiLimiter);
```

---

**`server/.env` — Database credentials in environment**

While `.gitignore` excludes `server/.env`, the Turso JWT `TURSO_AUTH_TOKEN` provides direct database access. If this leaks:
- Attacker has full read/write to entire database
- Can extract all user data, scores, leaderboard

**Recommendation**: Use a dedicated database user with limited permissions, not the root credential.

---

## Summary

| Severity | Issue |
|----------|-------|
| **Critical** | RevenueCat API key hardcoded in client bundle |
| **Critical** | No authentication on ALL backend endpoints |
| **Critical** | Client-controlled subscription status |
| **High** | Client-controlled scores/progress |
| **High** | No session ownership verification |
| **High** | Leaderboard based on untrusted scores |
| **Medium** | No rate limiting |
| **Medium** | DB credentials not principle of least privilege |

**Immediate actions**:
1. Rotate the RevenueCat API key and implement server-side billing verification
2. Add Firebase token authentication to all backend endpoints
3. Trust server-side subscription verification via webhooks, not client requests
4. Implement rate limiting to prevent abuse