# 📱 Hyderabad Guess The Place — Full Technical Spec

---

## 🧠 PRODUCT OVERVIEW

Build a **Flutter-based mobile quiz game** where users guess famous Hyderabad places based on **abstracted images**.

The app must:

* Work **offline after initial download**
* Use **downloadable content packs**
* Keep the **client lightweight and dumb**
* Provide a **fast, game-like experience**

---

## 🎯 CORE PRINCIPLES

* ⚡ Offline-first gameplay
* 🧩 Content delivered via packs
* 🔐 Minimal sensitive logic on client
* 📦 Preprocessed assets only (no runtime processing)
* 🚀 Smooth UX (animations, haptics, sound)

---

## 🧱 SYSTEM ARCHITECTURE

### 🔄 High-Level Flow

1. Admin creates content pack (locally)
2. Pack is uploaded to server/storage
3. App checks for latest version
4. User downloads pack
5. Game runs fully offline

---

## 📦 CONTENT PACK SYSTEM

### 📁 Pack Format

Each pack is a `.zip` file:

```
hyderabad_pack_v1.zip
```

### 📂 Inside Structure

```
/images/
  q1.jpg
  q2.jpg
  q3.jpg

/questions.json
/metadata.json
```

---

## 📄 QUESTIONS FORMAT

```json
{
  "version": 1,
  "category": "restaurants",
  "questions": [
    {
      "id": "q1",
      "image": "q1.jpg",
      "options": [
        "Paradise Biryani",
        "Bawarchi",
        "Shah Ghouse",
        "Cafe Niloufer"
      ],
      "correct_index": 0,
      "difficulty": "easy"
    }
  ]
}
```

---

## 📄 METADATA FORMAT

```json
{
  "version": 1,
  "city": "Hyderabad",
  "total_questions": 10,
  "size_mb": 8.5,
  "categories": ["restaurants", "cafes", "landmarks"]
}
```

---

## 🖼️ IMAGE PROCESSING PIPELINE (ADMIN SIDE)

### Input Sources:

* Google Places API (manual fetch)
* Manually collected images

### Processing Rules:

* Blur (multiple intensities)
* Crop (partial views)
* Zoom into region
* Reduce clarity
* Optional grayscale/masking

### Output:

* Multiple variants per place

Example:

```
charminar_blur_1.jpg
charminar_crop_2.jpg
```

---

## ⚙️ PACK GENERATION PIPELINE

### Steps:

1. Collect images
2. Process images
3. Create `questions.json`
4. Generate `metadata.json`
5. Zip everything

---

## 📱 CLIENT (FLUTTER)

### 📂 Local Storage

Store packs in:

```
/app_data/packs/
```

---

### 🚀 App Launch Flow

1. Check if pack exists
2. If not:

   * Prompt download
3. If exists:

   * Load pack into memory

---

### ⬇️ Pack Download Flow

1. Call:

   ```
   GET /packs/latest
   ```
2. Compare versions
3. If newer:

   * Prompt user
   * Download ZIP
   * Extract locally
   * Replace old pack

---

## 🎮 GAMEPLAY

### Quiz Screen:

* Show image
* Show 4 options
* User selects answer

### Feedback:

* Instant result
* Highlight correct answer
* Move to next question

---

## 🧠 SCORING

* +10 per correct answer
* Optional streak bonus
* Store score locally, sync later

---

## 🏆 LEADERBOARD

### Features:

* City-wide leaderboard
* Top 50 users

### Backend-driven

---

## 🔐 AUTHENTICATION

* Firebase Authentication
* Google Sign-In only

---

## 🌐 BACKEND (MINIMAL)

### Recommended:

nodejs

### APIs:

#### 1. Get Latest Pack

```
GET /packs/latest
```

Response:

```json
{
  "version": 2,
  "url": "https://server.com/hyderabad_pack_v2.zip",
  "size": "12MB"
}
```

---

#### 2. Submit Score

```
POST /score
```

Body:

```json
{
  "user_id": "abc",
  "score": 120
}
```

---

#### 3. Leaderboard

```
GET /leaderboard
```

---

## 🗃️ DATABASE (TURSO)

### users

* id (uuid)
* name
* email
* score
* created_at

---

### leaderboard

* user_id
* score

---

## 🎨 UX REQUIREMENTS

### Animations:

* Image fade-in
* Button press scale
* Smooth transitions

### Haptics:

* Correct → success vibration
* Wrong → error vibration

### Sound Effects:

* Correct → ding
* Wrong → buzz

---

## 📦 INITIAL DATASET (MVP)

Minimum 10 places:

* Charminar
* Hussain Sagar
* Paradise Biryani
* Cafe Niloufer
* Tank Bund
* Inorbit Mall
* Sarath City Capital Mall
* Ramoji Film City
* Taj Krishna
* Hyderabad Metro

---

## 🔐 SECURITY NOTES

* No API keys in client
* No runtime image fetching
* All assets pre-downloaded
* Accept that answers exist locally (MVP tradeoff)

---

## ⚡ PERFORMANCE

* Preload next question image
* Use local file paths only
* Avoid heavy computation on client

---

## 🔄 UPDATE SYSTEM

* App checks version on launch
* Prompt user to update pack
* Replace local pack after download

---

## 💰 MONETIZATION

Use RevenueCat:

* Unlock premium packs
* Remove ads (future)

---

## 🚀 FUTURE ROADMAP

* Daily challenges (downloadable mini packs)
* Multiplayer mode
* Timed quizzes
* Multiple cities (Mumbai, Bangalore, Delhi)
* User-generated packs

---

## 🧪 DEVELOPMENT STRATEGY

### Phase 1:

* Static pack (10 questions)
* Core gameplay loop

### Phase 2:

* Pack download system
* Leaderboard

### Phase 3:

* Animations + polish

### Phase 4:

* Monetization

---

## 🧠 KEY DESIGN DECISIONS

* Use packs instead of CDN
* Preprocess everything
* Keep client dumb
* Minimal backend
* Scale via content, not infra

---

## ✅ FINAL GOAL

A fast, addictive, offline-first quiz app that feels like a game and can scale easily across cities using content packs.

---
