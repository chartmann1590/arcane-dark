# Arcane Dark Privacy Policy

_Last updated: September 11, 2026_

## The short version

When you play solo, your story stays on your phone. We never see it, store it, or sell it. Arcane Dark only talks to the internet for four things: downloading the AI model once, syncing a multiplayer game you choose to join, showing ads, and transmitting content safety reports you explicitly submit.

## Solo play

Everything about your solo campaigns — your character, your choices, the story the AI tells you — is generated and stored only on your device. It is never uploaded anywhere. You can play entirely offline (after the one-time AI model download) and nothing about your adventure ever reaches us or anyone else.

## Artificial Intelligence & Content Safety

Arcane Dark uses Artificial Intelligence (Google Gemma via LiteRT-LM) to dynamically generate interactive fantasy tabletop roleplaying narratives, Dungeon Master dialogue, and quest events. 

- **Safety Standards & Prohibited Use**: Arcane Dark strictly prohibits using the app to generate hateful, sexually explicit, abusive, harassing, self-harming, or dangerous content. We align with Google Gemma's Prohibited Use Policy and Google Play Generative AI Guidelines.
- **In-App AI Reporting Mechanism**: In compliance with Google Play Generative AI policies, players can flag and report any AI-generated narration directly within the app by tapping the flag icon on any scene card or through **Settings → AI Safety & Compliance → Report AI Content / Issue**.
- **How Reports are Processed**: When you submit an AI content report, the reported excerpt, your selected violation category (offensive, hate speech, sexual content, violence, hallucination, or other), optional comments, app version, and timestamp are securely sent via encrypted HTTPS to our Cloudflare Worker reporting endpoint (`arcane-dark-reports.charles-h-hartmann1.workers.dev`).
- **Data Retention & Moderation**: Submitted reports are stored in secure, access-controlled Cloudflare KV storage and reviewed by our trust and safety moderation team solely to enforce community safety, improve AI guardrails, and prevent harmful outputs. We never sell report data or use it for advertising.

## Multiplayer play

If you create or join a multiplayer session, the game state needed to keep everyone in sync — character stats, party position, quest progress, and the messages you send during that session — is stored in Google Firebase so other players in your session can see it. This data is tied to an anonymous account, not your name or email (we never ask for either). It stays only as long as your session, plus a short retention window for troubleshooting.

## Advertising

Arcane Dark shows ads through Google AdMob to support ongoing development. AdMob may collect device identifiers (such as your advertising ID) and use them to serve ads, including personalized ads where permitted. 
- **Consent Management**: If you are in the UK or European Economic Area (EEA), you will be presented with a Google User Messaging Platform (UMP) consent screen the first time you open the app.
- **Managing Your Choices**: You can review, modify, or withdraw your advertising consent choices at any time by navigating to **Settings → Privacy Choices**.
- We do not control what AdMob itself does with data beyond what Google discloses in the [Google Privacy & Terms](https://policies.google.com/technologies/ads).

## Crash and performance data

We use Firebase Crashlytics and Firebase Performance Monitoring to catch crashes and optimize responsiveness. These send technical diagnostics — device model, operating system version, app version, and exception stack traces — never your campaign stories, character backstories, or user input.

## Children

Arcane Dark is not directed at children under 13, and we do not knowingly collect personal information from children. Ads shown in this app are not configured for child-directed treatment.

## Your choices

- **Play solo and offline**: Nothing leaves your device.
- **Flag or report AI content**: Instantly report inappropriate outputs via the in-app reporting button.
- **Manage or withdraw ad consent**: Anytime from **Settings → Privacy Choices**.
- **Delete campaign / hero**: Delete any character or campaign directly from within the app, removing it from device storage immediately.
- **Uninstalling**: Removes all local databases, cached campaign states, and downloaded AI model weights.

## Account & Data Deletion

In compliance with Google Play's User Data & Account Deletion Policy, users can request full deletion of their account and all associated data stored on our servers:

1. **In-App Immediate Deletion**: When signed in, navigate to **Settings → Account → Delete Account & Cloud Data** to permanently delete your Firebase authentication credentials and all cloud-synced characters immediately.
2. **Web Deletion Request Portal**: Users who have uninstalled the app or lost access can submit an account deletion request online via our [Account & Data Deletion Portal](https://chartmann1590.github.io/arcane-dark/delete-account.html).
3. **Direct Email Request**: Email [charles.h.hartmann1@gmail.com](mailto:charles.h.hartmann1@gmail.com?subject=Arcane%20Dark%20Account%20and%20Data%20Deletion%20Request) with the subject line *"Arcane Dark Account and Data Deletion Request"* and your registered email address. Requests are verified and fulfilled within 48 hours.

**What is deleted**: All authentication identifiers (UID, email, authentication tokens) and Firestore character rosters (`users/{uid}/characters`). No personal data is retained.

## Third parties this app uses

- **Google Firebase**: Authentication, Firestore (multiplayer sync), Crashlytics, Performance Monitoring
- **Google AdMob**: Banner and interstitial advertisements
- **Cloudflare Workers & KV**: Secure transmission and storage of AI safety reports and content moderation
- **Hugging Face**: Initial one-time download of the open-source Gemma model file

Each third-party service operates under its respective privacy policy.

## Changes to this policy

If this policy changes in a material way, we will update the "Last updated" date above and announce updates through our store listing notes.

## Contact

Questions or concerns regarding this policy or AI safety reports can be directed to the contact address listed on the Google Play Store page or via [GitHub Issues](https://github.com/chartmann1590/arcane-dark/issues).
