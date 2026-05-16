# AI Quran Islam Diary — Onboarding Specification (v2)

## Overview

20-screen interactive onboarding flow designed to build emotional investment and deliver personalized AI spiritual moments. Story structure: **Introduction → Reflection Bank (AI Analogies) → Climax → Conclusion**.

**Philosophy:** Every screen adds value and delivers a personalized AI moment that brings the user closer to Allah. By screen 15, the user has invested real time → loss aversion drives commitment to their spiritual journey.

### Key Design Decisions
- **PageView** with 20 pages, programmatic navigation (not swipeable)
- **Linear progress** indicator at top ("Step 3 of 20")
- **Back button** available from screen 2+
- **All data** stored in `OnboardingData` model, persisted to `SharedPreferences` on completion
- **AI analogies** generated via OpenRouter free models (reuses existing backend infrastructure)

---

## Screen-by-Screen Breakdown

### PART 1: INTRODUCTION (Screens 1–6)

| # | Screen | Content | Notes |
|---|--------|---------|-------|
| 1 | **Welcome** | Mascot logo + "Assalamualikum" + Mascot 'hi.webp' + "waalikum" button | Warm, mascot-led entry |
| 2 | **Problem + Solution** | Pain: "Life flies by — distractions, missed prayers, spiritual distance" → Solution: 4 feature cards (Diary, Tasbih, Quran, Prayer Times) | Problem/solution clarity |
| 3 | **Your Name** | "What should we call you?" + TextField (optional, 24 char max) + Skip | Personalization builds trust |
| 4 | **Age + Phone Usage** | Age picker + "Hours on phone daily?" slider → sets up bombshell | Data collection for aha moment |
| 5 | **The Bombshell** | Personalized stat: "This year, you'll spend ~X hrs on your phone. If just 10% became reflection, that's Y hours of spiritual growth." | First aha moment |
| 6 | **The Bridge** | "It doesn't have to be this way. Let's build your personal path to Allah." + "Start" button | Hope + forward path |

### PART 2: REFLECTION BANK — AI ANALOGIES (Screens 7–14)

Each pair: **Question** (pills + optional free-text) → **Reveal** (AI analogy fades in). 4 pairs total.

| # | Screen | Question | Pills | Custom Option |
|---|--------|----------|-------|---------------|
| 7 | **Q1: Your Intention** | "What do you seek most in your journey?" | • Deeper connection with Allah<br>• Quran consistency<br>• Peace & stillness<br>• Gratitude & contentment | ✏️ Write your own |
| 8 | **Reveal 1** | ✨ AI analogy based on their intention | — | — |
| 9 | **Q2: Your Heart** | "How does your heart feel right now?" | • Restless / Yearning<br>• Grateful / At peace<br>• Overwhelmed / Heavy<br>• Hopeful / Excited | ✏️ Write your own |
| 10 | **Reveal 2** | ✨ AI analogy based on their heart state | — | — |
| 11 | **Q3: Your Challenge** | "What's your biggest barrier?" | • Finding time<br>• Staying consistent<br>• Distractions<br>• Lack of motivation | ✏️ Write your own |
| 12 | **Reveal 3** | ✨ AI analogy based on their challenge | — | — |
| 13 | **Q4: Your Journey** | "How would you describe your spiritual walk?" | • "I want to be better every day"<br>• "I'm trying my best, but..."<br>• "I feel distant but want to return" | ✏️ Write your own (multi-line) |
| 14 | **Reveal 4** | ✨ AI analogy + summary of all 4 analogies | — | — |

### PART 3: CLIMAX (Screens 15–17)

| # | Screen | Content | Notes |
|---|--------|---------|-------|
| 15 | **First Diary Entry** | Full diary UI — gratitude text field + tags + save | In-app experience demo |
| 16 | **AI Insight** | Based on entry: greeting + Islamic insight + Quran verse/Hadith + tags | Reuses existing insight pipeline |
| 17 | **Congratulations + Streak** | Confetti 🎉 + "Day 1 of your journey closer to Allah!" + streak counter + Review prompt | Emotional peak |

### PART 4: CONCLUSION (Screens 18–20)

| # | Screen | Content | Notes |
|---|--------|---------|-------|
| 18 | **Personalized Summary** | "Your Spiritual Profile" — name, intention, analogy, streak, diary preview | Makes it feel tailored |
| 19 | **Commitment + Social Proof** | "How committed are you?" (Cialdini consistency) + "Join thousands reflecting every day" | Psychological priming |
| 20 | **Setup → Homepage** | Notifications + Location permissions → "Start Reflecting" → Homepage | Functional setup |

---

## AI Features

### Analogy Generation
- **Endpoint:** `POST /api/generate-analogy` (backend/index.js)
- **Request:** `{ uid, question, answer }`
- **Response:** `{ analogy: "..." }`
- **Provider:** OpenRouter free models (same chain as existing insights)
- **Prompt:** "Generate a poetic Islamic analogy comparing the user's answer to something beautiful in nature/spirituality. 2-3 sentences. Optionally include a Quranic or Hadith reference."

### Diary Insight (Existing)
- As soon as user saves their first diary entry (Screen 15), `triggerBackgroundInsight()` fires
- Screen 16 loads the result from Firestore

---

## Data Model

```dart
class OnboardingData {
  String? displayName;
  int? age;
  int? phoneHours;
  
  // Analogy answers
  String? intentionAnswer;
  String? heartAnswer;
  String? challengeAnswer;
  String? journeyAnswer;
  
  // AI analogies
  String? intentionAnalogy;
  String? heartAnalogy;
  String? challengeAnalogy;
  String? journeyAnalogy;
  
  // Diary
  String? diaryEntry;
  List<String> diaryTags;
  
  // Commitment
  String? commitmentLevel;
  
  // Permissions
  bool notificationsEnabled;
  bool locationEnabled;
}
```

---

## Files

### New Files
| File | Purpose |
|------|---------|
| `lib/screens/onboarding_screen.dart` | Main PageView orchestrator, OnboardingData model, all 20 page widgets |
| `lib/services/analogy_service.dart` | API client for POST /api/generate-analogy |

### Modified Files
| File | Change |
|------|--------|
| `backend/index.js` | Add `POST /api/generate-analogy` endpoint |
| `lib/main.dart` | Check `onboarding_complete` from SharedPreferences; route to onboarding if not complete |

---

## Visual Styling

- **Progress bar:** Linear, 20 segments via `LinearProgressIndicator`
- **Page transitions:** 300ms `Curves.easeInOutCubicEmphasized` (matches existing app)
- **Pills:** M3 `ChoiceChip`, teal accent when selected, haptic feedback
- **AI analogy card:** Gradient card with sparkle icon, 500ms fade-in + slide-up
- **Background:** Material 3 expressive gradient (same as existing app — `primaryContainer`/`secondaryContainer` wash)
- **Typography:** `GoogleFonts.interTextTheme()` (matches existing app)
- **Colors:** Deep teal `#006A60` primary, matching existing design system
