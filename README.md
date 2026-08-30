# Arcane Dark

<p align="center">
  <a href="https://chartmann1590.github.io/arcane-dark/"><img src="https://img.shields.io/badge/Website-arcane--dark-8B5CF6?style=for-the-badge&logo=sparkles&logoColor=white" alt="Website"/></a>
  <a href="https://chartmann1590.github.io/arcane-dark/privacy.html"><img src="https://img.shields.io/badge/Privacy-Solo%20stays%20on--device-3DD68C?style=for-the-badge" alt="Privacy"/></a>
  <img src="https://img.shields.io/badge/Coming%20soon-Google%20Play-000000?style=for-the-badge&logo=googleplay&logoColor=white" alt="Coming soon to Google Play"/>
</p>

<p align="center">
  <strong>Your AI Dungeon Master lives on your phone.</strong><br/>
  A cozy, torch-lit D&amp;D adventure you can play anywhere — solo and private, or with up to 5 friends around one table.<br/>
  <em>No subscriptions. No waiting. Your story, your way.</em>
</p>

<p align="center">
  <a href="https://chartmann1590.github.io/arcane-dark/"><strong>🌐 Official website → chartmann1590.github.io/arcane-dark</strong></a> •
  <a href="https://chartmann1590.github.io/arcane-dark/privacy.html">Privacy</a> •
  <a href="#-peek-inside">Screenshots</a>
</p>

<p align="center">
  <a href="https://chartmann1590.github.io/arcane-dark/">
    <img src="https://img.shields.io/badge/Visit%20the%20beautiful%20website-8B5CF6?style=for-the-badge" alt="Visit website"/>
  </a>
</p>

> **🚀 Coming soon to Google Play for Android** — iOS planned for later. Follow this repo or the [website](https://chartmann1590.github.io/arcane-dark/) for the launch day link. The site, screenshots, and privacy policy are live today at **[chartmann1590.github.io/arcane-dark](https://chartmann1590.github.io/arcane-dark/)**.

---

### ✨ Why players love it

- **Your story stays private.** Solo quests live only on your phone — never uploaded, never sold. Play without an account if you like.
- **Adventure anywhere — no signal needed.** After a quick setup, solo works fully offline. Perfect for planes, cabins, or the couch.
- **Make a hero you love.** Pick ancestry, calling, and background, then shape looks step-by-step with a live portrait preview.
- **A new dungeon every time.** Ever-changing maps with cozy fog-of-war — explore at your own pace.
- **Bring your friends.** Host or join — up to 6 share the same map and story. Invite with a code or QR.

### 🎮 How it feels to play

1. **Make your hero** — who you are, how you fight, what you carry.
2. **Step into the dark** — say what you do: *“I inspect the altar,” “I try to talk them down.”*
3. **Watch the story answer** — your AI Dungeon Master replies line by line, dice and all.

### 🔒 Privacy, plain and simple

Solo = offline & private. That’s the whole point of an on-device Dungeon Master. Multiplayer only shares what the table needs to stay in sync (and you can delete any hero or campaign with a tap).

Full policy: **[chartmann1590.github.io/arcane-dark/privacy.html](https://chartmann1590.github.io/arcane-dark/privacy.html)** (also in [`PRIVACY.md`](PRIVACY.md) and in-app under Settings → Privacy Policy).

---

### 👀 Peek inside

<p align="center"><em>From the app’s own dark-fantasy design — deep violet, warm gold, soft tavern light. Tap to enlarge on the website.</em></p>

<table>
  <tr>
    <td align="center" width="20%"><a href="https://chartmann1590.github.io/arcane-dark/screenshots/01-onboarding.svg"><img src="docs/screenshots/01-onboarding.svg" alt="Welcome screen — quick setup then offline solo" width="160"/></a><br/><sub><strong>Welcome</strong><br/>Quick setup, then offline</sub></td>
    <td align="center" width="20%"><a href="https://chartmann1590.github.io/arcane-dark/screenshots/02-character-creation.svg"><img src="docs/screenshots/02-character-creation.svg" alt="Character creation — ancestry, class, looks" width="160"/></a><br/><sub><strong>Your Hero</strong><br/>Ancestry, calling, looks</sub></td>
    <td align="center" width="20%"><a href="https://chartmann1590.github.io/arcane-dark/screenshots/03-campaign-hub.svg"><img src="docs/screenshots/03-campaign-hub.svg" alt="Home — current campaign and heroes" width="160"/></a><br/><sub><strong>Home</strong><br/>Campaigns & heroes</sub></td>
    <td align="center" width="20%"><a href="https://chartmann1590.github.io/arcane-dark/screenshots/04-gameplay.svg"><img src="docs/screenshots/04-gameplay.svg" alt="At the table — map, dice, living story" width="160"/></a><br/><sub><strong>At the Table</strong><br/>Map, dice, story</sub></td>
    <td align="center" width="20%"><a href="https://chartmann1590.github.io/arcane-dark/screenshots/05-multiplayer.svg"><img src="docs/screenshots/05-multiplayer.svg" alt="With friends — QR and party up to 6" width="160"/></a><br/><sub><strong>With Friends</strong><br/>QR invite, up to 6</sub></td>
  </tr>
</table>

> All screenshots are high-fidelity mockups from the app’s design system. Real device captures will replace them after the Play Store launch. Files live in [`docs/screenshots/`](docs/screenshots/) and on the [website #screenshots](https://chartmann1590.github.io/arcane-dark/#screenshots).

---

### 📲 Get it

**Coming soon to Google Play — Android first, iOS later.**

[![Coming soon on Google Play](https://img.shields.io/badge/Coming%20soon%20on-Google%20Play-000000?style=for-the-badge&logo=googleplay&logoColor=white)](https://chartmann1590.github.io/arcane-dark/)

- **Website (live today):** [https://chartmann1590.github.io/arcane-dark/](https://chartmann1590.github.io/arcane-dark/)
- **Privacy on the web:** [https://chartmann1590.github.io/arcane-dark/privacy.html](https://chartmann1590.github.io/arcane-dark/privacy.html)
- **Store link:** We’ll post it here and on the website the moment it’s approved — follow the repo to be notified.

### 💬 Questions or ideas?

Open an issue — we read them. Want a peek under the hood? The whole project is open on GitHub.

<details>
<summary><strong>🛠️ For the curious / developers (click to expand)</strong></summary>

This is a Flutter app. Architecture and build notes are in [`plan/`](plan/) — start with [`plan/00-overview.md`](plan/00-overview.md).

**You’ll need:** Flutter 3.35+, Dart 3.9+, an Android device or emulator (API 26+). The AI model (~2.6GB) downloads on first run from Hugging Face per `assets/model_manifest.json`.

```bash
flutter pub get
flutter run
```

**Before you ship your own build:** swap the placeholder AdMob IDs in `lib/services/ad_config.dart`, `android/app/src/main/AndroidManifest.xml`, and `ios/Runner/Info.plist`, add your own `google-services.json` / `GoogleService-Info.plist` (see `plan/06-multiplayer-firebase-backend.md`), and check `plan/09-testing-polish-launch.md`.

- `lib/` — Flutter app (`features/`, `domain/`, `services/`, `providers/`)
- `android/` / `ios/` — native projects (Android has a hand-written Kotlin `LlmEngine.kt` bridge to LiteRT-LM)
- `plan/` — phase-by-phase design & build plan
- `docs/` — the GitHub Pages site you’re on (`index.html`, `privacy.html`, `screenshots/`, `sitemap.xml`, `robots.txt`)

</details>

---

### License

No license has been chosen yet. All rights reserved unless a `LICENSE` file says otherwise.

<p align="center"><em>© 2026 Arcane Dark • <a href="https://chartmann1590.github.io/arcane-dark/">Website</a> • <a href="https://chartmann1590.github.io/arcane-dark/privacy.html">Privacy Policy</a> • Coming soon to Google Play</em></p>
