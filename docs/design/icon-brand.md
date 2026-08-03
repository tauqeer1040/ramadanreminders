# App Icon Brand Guidelines

## Current App (Meowmin Ai Diary — Ramadan)

### Icon
- **Image:** `assets/photos/mascot/face.png` (cat mascot face)
- **Background:** Golden sunset gradient
  - Top: `#735C12` (deep amber-gold)
  - Mid: `#C49B2A` (warm harvest gold)
  - Bottom: `#F5E6A3` (soft cream gold)
- **Shape:** Adaptive icon (rounded square on Android, rounded rectangle on iOS)

### Why these colors
- Evokes a golden sunset / golden moon — warm, spiritual, serene
- Deliberately avoids orange/saffron (`#CC4400` range) to prevent association with Hindu faith symbolism
- The warm gold pops well in the app drawer among mostly blue/white icons
- The cream bottom (`#F5E6A3`) gives a soft, approachable finish

### Gradient files
- Android drawable: `android/app/src/main/res/drawable/ic_launcher_background_gradient.xml`
- Raster fallback: `assets/photos/elements/icon_bg_gradient.png`
- `pubspec.yaml` `adaptive_icon_background` hex: `#735C12` (fallback)

---

## Future: Meom (Hindu Ai Diary variant)

Reuse the same icon image (`face.png`) and golden gradient background.

The cat mascot (`face.png`) is faith-neutral and works for both apps.

The gradient's golden/sunset warmth is universal and won't conflict with Hindu branding.
Use the same `ic_launcher_background_gradient.xml` drawable.

The orange pop that worked so well for Ramadan's app drawer discoverability
carries over naturally to Meom because the gradient reads as warm gold, not saffron.
