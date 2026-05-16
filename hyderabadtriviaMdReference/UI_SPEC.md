# Hyderabad Trivia - UI/Design Spec

## Visual Style
- **Theme**: Dark mode with warm orange accent (#E85D04)
- **Background**: Pure black (#000000)
- **Cards**: Dark grey (#1A1A1A) with rounded corners (28-36dp)
- **Typography**: Bold weights, large numbers for score
- **Animations**: Jelly effect on score change, confetti on milestones

## Color Palette
- Primary accent: #E85D04 (orange)
- Score positive: #FFC650 (gold)
- Score negative: #FF6C76 (red)
- Success: #4CBF7A (green)
- Error: #E27175 (pink-red)
- Option buttons: Pastel gradient (mint, lavender, salmon, yellow)

## Layout
- Bottom navigation: 2 tabs (Home, Profile)
- Quiz: Vertical carousel, one question per screen
- Top bar: Logo left, leaderboard center, score right
- Question: Image (56%) + Options (44%)
- Trivia overlay: Glassmorphism card with answer feedback

## Animations
- **Score jelly**: Scale + stretch on point gain/loss
- **Confetti**: Stars + circles on high score (score == bestScore) or streak >= 3
- **Trivia slide**: Elastic slide-in from bottom
- **Option press**: Scale down to 0.97
- **Image zoom**: Subtle 1.5 scale on long press (reveals "Where is this?" text)

## Duolingo-Inspired Ideas (Planned)
- Hearts/lives system
- XP instead of score
- Streak days counter
- Progress bar for lesson
- Duo mascot
