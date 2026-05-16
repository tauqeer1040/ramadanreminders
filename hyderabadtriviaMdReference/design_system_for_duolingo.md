# Design System: Duolingo "Purple Night" Edition

## 1. Visual Theme & Atmosphere: "The Midnight Quest"

This design system transforms the application into a tactile, high-stakes nocturnal adventure. While inspired by Duolingo’s playful geometry, the "Purple Night" theme replaces the bright daytime aesthetic with a deep-space arcade vibe. Every element is designed to feel like a physical "toy" or a neon-lit interface from a futuristic game console.

**Key Characteristics:**
- **The Deep Canvas:** A near-black, high-contrast background that makes neon accents "pop."
- **3D Tactility:** Buttons and cards aren't just flat surfaces; they have "weight" and "depth" (solid bottom shadows).
- **Chunky Interaction:** Large touch targets (52px–60px buttons) and generous, rounded corners (16px–24px).
- **Gamified Feedback:** Progress bars with gradients, "sparkle" highlights, and speech-bubble style notifications.

---

## 2. "Purple Night" Color Palette

### Base Surfaces (The Foundations)
- **Night Canvas:** `#0B0C15` — The primary page background.
- **Midnight Surface:** `#16172B` — Used for cards, sidebars, and navigation headers.
- **Deep Slate:** `#2D2F4D` — Used for inactive states or secondary borders.

### Action & Interaction (The Neon Swatch)
- **Neon Purple (Primary):** `#9D50FF` — Main branding and primary action buttons.
- **Deep Purple (3D Shadow):** `#7B39D1` — The "depth" layer for primary buttons.
- **Electric Cyan (Accent):** `#00F0FF` — Secondary actions, links, and "level-up" moments.
- **Midnight Cyan (3D Shadow):** `#00B8C4` — The "depth" layer for cyan buttons.

### Feedback & Status (The Game States)
- **Quest Green (Success):** `#72FF13` — Correct answers, streaks, and completed bars.
- **Dark Forest (3D Shadow):** `#57C20F` — The "depth" layer for success elements.
- **HP Red (Error):** `#FF4B4B` — Mistakes, alerts, and "hearts" lost.
- **Crimson (3D Shadow):** `#D13939` — The "depth" layer for error elements.
- **Star Gold (Warning):** `#FACC15` — Tips, rewards, and premium highlights.

### Typography (Readability)
- **Star White:** `#F1F1F1` — Primary text on dark backgrounds.
- **Ghost Silver:** `#A0A0B8` — Secondary/muted text.

---

## 3. Spacing & Layout: "The Atomic Quest"

We've abandoned the Clay spacing for a strictly **4px/8px atomic grid**. Everything must be a multiple of 8 (or 4 for fine-tuning).

### The Spacing Scale
| Name | Value | Use Case |
|------|-------|----------|
| `space-xxs` | 4px | Fine-tuning, internal small labels. |
| `space-xs` | 8px | Text-to-text, icon-to-text. |
| `space-s` | 16px | Standard internal padding (small cards). |
| `space-m` | 24px | **Standard Chunky Padding** (main cards). |
| `space-l` | 32px | Section gutters. |
| `space-xl` | 48px | Large vertical separation between "quest" steps. |
| `space-xxl`| 64px | Hero-to-content separation. |

### Layout Principles
- **The "Vertical Quest":** Content should follow a clear, single-column path when possible to mimic the "Duolingo Tree."
- **Chunky Margin:** Cards never touch; they "float" with at least 32px of gutter between them.

---

## 4. Typography Rules

### Font Families
- **Primary:** `Fredoka` (Rounded, Bold, Playful). Fallback: `Quicksand` or `Arial Rounded MT Bold`.
- **Monospace:** `Space Mono` (for stats/codes).

### Hierarchy (Purple Night Scale)
| Role | Size | Weight | Line Height | Letter Spacing |
|------|------|--------|-------------|----------------|
| **Boss Heading** | 48px | 700 | 1.10 | -1px |
| **Quest Title** | 32px | 700 | 1.20 | -0.5px |
| **Card Header** | 24px | 600 | 1.20 | normal |
| **Body Large** | 18px | 500 | 1.50 | normal |
| **Body Standard**| 16px | 400 | 1.50 | normal |
| **Small Label** | 14px | 600 | 1.20 | 0.5px (Caps) |

---

## 5. Component Stylings: "The 3D Interaction"

### The "Depressible" 3D Button
The signature interaction. Buttons do not hover; they "feel" physical.
- **State: Default**
  - Background: Neon Color (e.g., `#9D50FF`).
  - Border-bottom: **4px solid** Depth Color (e.g., `#7B39D1`).
  - Radius: 12px–16px.
  - Padding: 16px 24px.
- **State: Active (Clicked/Pressed)**
  - `transform: translateY(2px)`.
  - `border-bottom-width: 2px`.
  - Shadow "disappears" into the floor.

### The "Neon Floating" Card
- **Background:** `#16172B` (Midnight Surface).
- **Border:** **2px solid** `#2D2F4D` (Deep Slate).
- **Radius:** 20px (Chunky and friendly).
- **Shadow:** No blur. Use a solid 4px offset shadow (`rgba(0,0,0,0.3) 0px 4px`).

### The "Quest" Progress Bar
- **Track:** `#2D2F4D` (Deep Slate), 16px height, 20px radius.
- **Fill:** Gradient (e.g., Neon Purple to Electric Cyan).
- **Highlight:** A 4px tall semi-transparent white "glimmer" line on the top 20% of the fill to give it a 3D glass look.

---

## 6. Suggested Changes for the App

1.  **Navigation Transformation:**
    - Replace standard top-nav with a **Sidebar (Desktop)** or **Bottom Bar (Mobile)** using large, chunky icons.
2.  **Interaction Model:**
    - Every clickable element should have the **4px 3D bottom border**.
3.  **Visual Language:**
    - Add **"Speech Bubbles"** for tooltips and help text.
    - Use **"Progressive Disclosure"**—show one "Quest Step" (one card) at a time.
4.  **Feedback Loop:**
    - When a user finishes a task, trigger a **"Success State"** where the background flashes `Quest Green`.

---

## 7. Comparison: Clay vs. Duolingo Night

| Feature | Clay | Duolingo Night (This System) |
|---------|------|------------------------------|
| **Palette** | Warm Cream / Artisanal | Deep Space / Neon Arcade |
| **Borders** | 1px Oat / Dashed | 2px Slate / 4px 3D Bottoms |
| **Animation**| 8deg Tilt / Upward Jump | 3D Press Down / Vertical Pathing |
| **Radii** | 24px–40px (Organic) | 12px–20px (Geometric/Toy-like) |
| **Spacing** | Generous/Paper-like | Chunky/Atomic 8px Units |
