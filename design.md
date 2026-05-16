# Design System: AI Quran Islam Diary — Material 3 Expressive Premium Edition
## 1. Visual Theme & Atmosphere
Blends warm, tactile design language with Material 3 Expressive guidelines to create a premium, native Android experience for the AI Quran Islam Diary. Centers on spiritual calm and building a daily connection with Allah, with dynamic color support (falling back to deep teal `#006A60` seed) and Inter typography for a clean, premium feel.

**Key Characteristics:**
- **Dynamic Canvas:** Adapts to system dynamic color via `DynamicColorBuilder`, with deep teal (`#006A60`) fallback for non-dynamic devices
- **Premium Tactility:** Material 3 elevation, haptic feedback, and smooth expressive motion
- **Spiritual Calm:** Uncluttered layouts, high contrast for low-light use, gold accents (`#D4AF37`) for premium features
- **Native Android Feel:** Follows Material 3 component guidelines, favoring touch-optimized ripples and state layers
- **8px/4px Spacing Grid:** Aligned with Material 3 spacing for atomic consistency

---
## 2. Color Palette & Roles
### Base Surfaces (Material 3 Tokens)
- **Primary:** `#006A60` (Deep Teal) — Branding, primary actions
- **Primary Container:** `#E0F2F1` (Light Teal) — Secondary backgrounds, FAB container
- **On Primary:** `#FFFFFF` — Text/icons on primary
- **Secondary:** `#4DB6AC` (Light Teal) — Secondary actions
- **Surface:** `#F5F5F5` (Light) / `#121212` (Dark) — Page background
- **Surface Variant:** `#E0E0E0` (Light) / `#2D2D2D` (Dark) — Card backgrounds

### Premium & Accent Swatches
- **Premium Gold:** `#D4AF37` — Premium badges, achievement highlights
- **Dhikr Success:** `#4CAF50` — Completed dhikr, milestones
- **Error:** `#F44336` — Deleted entries, failed actions
- **Prayer Time Accent:** `#2196F3` — Prayer time highlights

---
## 3. Typography Rules
### Font Families
- **Primary:** `Inter` (Google Fonts)
- **Arabic/Quran:** `Amiri` (loaded in `pubspec.yaml`)

### Hierarchy
| Role | Size | Weight | Line Height | Notes |
|------|------|--------|-------------|-------|
| Display Large | 57px | 400 | 1.12 | Greeting headers, premium sheet titles |
| Headline Large | 32px | 600 | 1.25 | Section headings (Diary, Tasbih) |
| Title Large | 22px | 600 | 1.27 | Card titles, diary headers |
| Body Large | 16px | 400 | 1.50 | Primary body text, diary content |
| Label Large | 14px | 500 | 1.43 | Button text, navigation labels |
| Dhikr Counter | 48px | 700 | 1.00 | Large dhikr count |

---
## 4. Component Stylings
### Buttons (Material 3 Expressive)
- **Primary FilledButton:** Background `Primary`, foreground `On Primary`, 16px radius
- **Premium FilledButton:** Background `Premium Gold`, foreground `#000000`, 16px radius
- **OutlinedButton:** Border `Primary`, foreground `Primary`, 12px radius

### Cards (Material 3 Variants)
- **Diary Card:** `FilledCard`, surface variant background, 12px radius, 1dp elevation, 16px padding
- **Dhikr Card:** `ElevatedCard`, primary container tint, 12px radius, 2dp elevation
- **Prayer Time Card:** `OutlinedCard`, surface background, 8px radius

### Navigation
- **NavigationBar:** Indicator `Secondary Container`, 4px indicator radius, haptic feedback on select
- **Bottom Sheet:** M3 spec with drag handle, 16px radius, 24px horizontal padding

---
## 5. Layout Principles
### Spacing Grid
| Name | Value | Use Case |
|------|-------|----------|
| `space-xxs` | 4px | Small gaps |
| `space-xs` | 8px | Card internal padding |
| `space-s` | 16px | Standard card padding |
| `space-m` | 24px | Page margins |

### Layout Rules
- **Generous Whitespace:** 24px minimum padding between cards for a premium feel
- **Touch Targets:** Minimum 48px targets for all interactive elements

---
## 6. Motion & Animation
### Material 3 Expressive Curves
- **Page Transitions:** `ZoomPageTransitionsBuilder`
- **Component Animations:** `Curves.easeInOutCubicEmphasized`
- **Dhikr Counter:** Scale up 1.1x on increment, 200ms duration

### Haptic Feedback
- **Navigation Tap:** `HapticFeedback.lightImpact()`
- **Dhikr Complete:** `HapticFeedback.mediumImpact()`
- **Premium Unlock:** `HapticFeedback.heavyImpact()`

---
## 7. Depth & Elevation
| Level | Elevation | Use |
|-------|-----------|-----|
| Level 0 | 0dp | Page background |
| Level 1 | 1dp | Filled cards, diary entries |
| Level 2 | 2dp | Dhikr cards, dialogs |
| Level 3 | 3dp | FAB, bottom sheet |

---
## 8. Do's and Don'ts
### Do
- Use dynamic color for native Android feel
- Apply `Inter` font globally, `Amiri` for Quran
- Use Premium Gold (`#D4AF37`) for achievements and premium features
- Add haptic feedback to all interactions
- Maintain generous whitespace for a premium atmosphere

### Don't
- Use low-contrast text
- Mix more than 2 accent colors per section
- Use custom shadows; stick to Material 3 elevation

---
## 9. Responsive Behavior
### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Phone | <600px | Single column, bottom nav |
| Tablet | 600px+ | Multi-column grid for diary and stats |

---
## 10. Agent Prompt Guide
### Quick Color Reference
- Primary: `#006A60`
- Premium Gold: `#D4AF37`
- Dhikr Success: `#4CAF50`

### Example Component Prompts
- "Create a diary card with Material 3 FilledCard, surface variant background, 12px radius, 16px padding."
- "Design a dhikr card with ElevatedCard, primary container tint, 2dp elevation, and a large counter."
