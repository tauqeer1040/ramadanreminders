# Hyderabad Trivia - Onboarding Specification

## Overview

Long-form onboarding flow with 16 pages: Introduction → Climax → Conclusion.

Philosophy: **The longer the onboarding, the better** (per Mau Baron's framework). Each screen adds value, builds emotional investment, and converts at peak moments.

---

## Page Flow (18 pages)

### Structure: Introduction → Climax → Conclusion

| # | Page | Type | Source | Notes |
|---|------|------|--------|-------|
| | | **PART 1: INTRODUCTION** | | |
| 1 | Welcome | Greeting | Hardcoded | "Kya haal hai miya? 😄👋" |
| 2 | Problem→Solution | Value prop | NEW | "How well do you really know Hyderabad?" |
| 3 | Residency | Choice | Hardcoded | Born & Raised, Living 1-5 yrs, etc. |
| 4 | Name | Input | Hardcoded | Text field, max 24 chars |
| 5 | Favorite | Choice | Hardcoded | Pick from 4 → becomes Card 1 |
| | | **PART 2: CLIMAX** | | |
| 6 | Card 1 - Image | Display | metadata.json | Show selected favorite image |
| 7 | Card 1 - Options | Quiz | metadata.json | 4 options from JSON |
| 8 | Card 1 - Feedback | Result | metadata.json | Correct/incorrect |
| 9 | Card 2 - Intro | Bridge | NEW | "One more..." |
| 10 | Card 2 - Image | Display | metadata.json | jewel_of_nizam image |
| 11 | Card 2 - Options | Trick | metadata.json | User picks any → marked "wrong" |
| 12 | Trick Reveal | Reveal | NEW | "We got you 😈 +50 XP!" |
| 13 | Confetti/Gift | Reward | flutter_confetti | Streak Day 1 |
| 14 | Review Prompt | Review | in_app_review | At peak happiness |
| | | **PART 3: CONCLUSION** | | |
| 15 | Age | Choice | Hardcoded | Age range (MOVED HERE) |
| 16 | Gender | Choice | Hardcoded | Optional (MOVED HERE) |
| 17 | Summary | Mirror | All data | Profile display |
| 18 | Dev Credit | Credit | Hardcoded | "Made with ❤️ in Hyd" |
| | Complete | Transition | - | → QuizScreen |

---

## Card Details

### Data Source

`assets/packs/ghibli_pack/metadata.json` - 22 quiz cards

---

### Card 1 - User's Favorite

**Flow:**
1. User picks Favorite (Step 5): Charminar / Golconda Fort / Birla Mandir / Cafe Niloufer
2. Card 1 Image (Step 6): Show `charminar.webp` (or selected image)
3. Card 1 Options (Step 7): Load `options` array from metadata.json
4. Card 1 Feedback (Step 8): Check against `correct_answer`

**Example - Charminar:**
```
Image: charminar.png
Question: What is this landmark?
Options: [Charminar, Golconda Fort, Mecca Masjid, Chowmahalla Palace]
Correct: Charminar
Feedback: "Correct!" / "Try again"
```

---

### Card 2 - The Trick

**Flow:**
1. Card 2 Image (Step 10): Show `jewel of nizam.webp` (The Minar restaurant)
2. Card 2 Options (Step 11): Load 4 options from metadata.json
3. Trick Logic: User picks ANY option → ALL marked "wrong"
4. Reveal (Step 12): "Haha, we got you! Here's 50 XP for falling for it 😈"

**Data - jewel_of_nizam:**
```
Image: jewel of nizam.webp
Question: What is this landmark?
Options: [Gol Bungalow, Jewel of Nizam, Adaa, Taj Falaknuma]
Note: The question framing makes all options feel wrong
Reveal: "Actually 'The Jewel of Nizam' refers to a legendary gemstone collection at Salar Jung Museum, but this is 'The Minar' restaurant!"
XP Reward: +50
```

---

## Data Persistence

### Storage: `QuizProgressStore`

| Data | When Saved | Key |
|------|-----------|-----|
| Player Name | After NamePage | `player_name` |
| Residency | After ResidencyPage | `residency` |
| Favorite Spot | After FavoritePage | `favorite_spot` |
| Age Range | After AgePage | `age_range` |
| Gender | After GenderPage | `gender` |
| Card 1 Correct | After Card 1 | Onboarding card completion |
| Onboarding XP | After Card 2 | `xp` +50 |
| Onboarding Complete | End | `onboarding_complete` = true |
| Streak | After Confetti | `streak_days` = 1 |

---

## Review Prompt

### Trigger 1: Peak Emotional Moment
- **When**: After confetti celebration (Step 13), before Summary
- **Why**: User is happiest - Mau Baron's 12% review rate proof
- **Implementation**: `in_app_review.requestReview()`

### Trigger 2: Return Visit
- **When**: Day 2+ return, if no review submitted yet
- **Implementation**: Check stored flag `review_prompted`, if false → prompt

---

## Component States

### Navigation
- PageView with 16 pages (never scrollable - programmatic navigation)
- Progress dots at top (7 dots for intro, hidden during climax?)
- Back button available from Step 3+

### Validation Per Page
```
Step 1 (Welcome): Can always continue
Step 2 (Problem): Can always continue
Step 3 (Residency): Required - must select one
Step 4 (Name): Required - must enter name
Step 5 (Favorite): Required - must select one
Step 6 (Card 1 Image): Auto-advance after 1.5s
Step 7 (Card 1 Options): Required - must select one
Step 8 (Card 1 Feedback): Auto-advance after 2s
Step 9 (Card 2 Intro): Auto-advance after 1.5s
Step 10 (Card 2 Image): Auto-advance after 1.5s
Step 11 (Card 2 Options): Required - must select one
Step 12 (Card 2 Reveal): Auto-advance after 3s
Step 13 (Confetti): Auto-advance after 3s
Step 14 (Review): User choice - continue always
Step 15 (Summary): Continue to Step 16
Step 16 (Dev Credit): Complete → onComplete()
```

---

## Audio Feedback

Use `AudioService.instance`:

| Event | Sound |
|------|-------|
| Answer selected | `playClick()` |
| Correct answer | `playCorrect()` |
| Wrong answer | `playWrong()` |
| Confetti | `playWin()` |
| Complete | `playWin()` |

---

## Visual Styling

### Background
- Intro (Steps 1-5): `assets/photos/onboarding.webp` + gradient overlay
- Climax (Steps 6-14): Solid `AppTheme.nightCanvas` or darker
- Conclusion (Steps 15-16): `assets/photos/app_bg2.webp` + 0.65 overlay

### Theme
- Primary: `AppTheme.neonPurple`
- Secondary: `AppTheme.electricCyan`
- Success: `AppTheme.questGreen`
- Error: `AppTheme.hpRed`
- XP Bonus: `AppTheme.starGold`

### Animations
- Page transitions: 260ms easeOutCubic
- Auto-advances: 1500ms-3000ms delays
- Confetti: `flutter_confetti` - celebration burst

---

## Files to Modify

| File | Action |
|------|--------|
| `lib/screens/onboarding_screen.dart` | Rewrite - major refactor |
| `lib/services/quiz_progress_store.dart` | Extend - add XP, review flag |
| `onboarding.md` | This file - documented |

---

## Implementation Notes

### Card Loading
```dart
// Load card from metadata.json by ID
Future<QuizCard?> _loadCard(String id) async {
  final jsonString = await rootBundle.loadString('assets/packs/ghibli_pack/metadata.json');
  final json = jsonDecode(jsonString);
  final cards = json['questions'] as List;
  return cards.firstWhere((c) => c['id'] == id);
}
```

### Trick Card State
```dart
// Always mark as "wrong" for Card 2
bool get isTrickCard => currentCardIndex == 1; // Card 2 is index 1
bool get isCorrect => isTrickCard ? false : selectedAnswer == correctAnswer;
```

### XP Award
```dart
// On Card 2 completion (trick revealed)
await QuizProgressStore.addXP(50);
```

### Review Tracking
```dart
// After review prompt shown
await QuizProgressStore.setReviewPrompted(true);
```

---

## Success Metrics

Target: Match Mau Baron's 12-15% conversion with extended onboarding.

- Download → Onboarding Start: 100%
- Onboarding Complete: Target 12-15%
- Review Submitted: Target 12% (at peak) + additional (return)
- Day 1 Retention: Track streak completion