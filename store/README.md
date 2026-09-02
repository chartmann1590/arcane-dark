# Arcane Dark — Play Store assets (source of truth)

This directory is the **source of truth** for Google Play listing assets. The same files are mirrored to:
- `docs/store/` (served on the GitHub Pages website)
- `fastlane/metadata/android/en-US/images/` (for `fastlane supply` automated uploads)
- `docs/assets/img/` (icon + feature graphic + promo thumbnail used by the website hero/promo sections)

## Icon
- `icon-512.png` — 512×512, 32-bit PNG with alpha (Play Store hi-res icon). Copy is at `fastlane/.../icon.png`.
- `icon-1024.png` — 1024×1024 master. Also at `docs/assets/img/icon-1024.png`.
- On-device: `android/app/src/main/res/mipmap-*/ic_launcher.png` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- App name on phone: **Arcane Dark** (`android:label` & `CFBundleDisplayName`)

## Feature graphic
- `feature-graphic.png` — 1024×500, RGB (no alpha) as required. Also at `docs/assets/img/feature-graphic.png` and `fastlane/.../featureGraphic.png`.

## Promo video
- `promo-thumbnail.png` — 1280×720 thumbnail used on the website (`docs/index.html#promo`) and as the Play Store promo still.
- Video YouTube URL (replace before submission): `https://www.youtube.com/watch?v=arcane-dark-promo` — stored in `fastlane/metadata/android/en-US/video.txt` and linked from `docs/index.html#promo`. Upload the 60s cut to YouTube and replace `arcane-dark-promo` with the real ID in both places.

## Screenshots — phone, 7″ tablet, 10″ tablet
All 5 screens × 3 sizes = 15 PNGs, each within Play specs (≥ 320px, ≤ 3840px, 16:9 or 9:16):

- `screenshots/phone/` — 1080×1920 (portrait) → `fastlane/.../phoneScreenshots/`
- `screenshots/7in/` — 1200×1920 → `fastlane/.../sevenInchScreenshots/`
- `screenshots/10in/` — 1600×2560 → `fastlane/.../tenInchScreenshots/`

Web gallery SVGs remain in `docs/screenshots/` and the PNG sets are shown at `https://chartmann1590.github.io/arcane-dark/#screenshots`.

## Fastlane metadata (en-US)
- `fastlane/metadata/android/en-US/title.txt` — Arcane Dark
- `fastlane/metadata/android/en-US/short_description.txt` — 80-char
- `fastlane/metadata/android/en-US/full_description.txt` — customer-facing long description
- `fastlane/metadata/android/en-US/video.txt` — YouTube promo URL
- `fastlane/metadata/android/en-US/changelogs/1.txt` — initial release notes

Swap `YOUTUBE_VIDEO_ID` and replace the placeholder screenshots with real device captures after launch if desired — the current renders already pass `fastlane` / Play Console validation.
