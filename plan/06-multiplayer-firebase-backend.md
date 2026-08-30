# Phase 06 — Multiplayer & Firebase Backend

**Goal:** 2–6 friends can join a shared session over the internet, see the same map/party state, and take turns while one host device runs the AI DM. Everything fits inside Firebase's **Spark (free) plan** limits.

**Depends on:** Phase 01 (Firebase project), Phase 03 (`CampaignState` schema), Phase 05 (map/position schema). Phase 07's mockups for this phase's UI are done: Multiplayer Lobby (`projects/6748340587166257171/screens/d942a70e24f44aa3b6c3b79423b25b34`), Join a Campaign (`.../140d51696d774c14a226b23ba507483e`) — see `07-ui-design-stitch.md`'s Screen registry.
**Enables:** Phase 09 (final QA needs a working multiplayer path).

## Architecture: host-authoritative, no Cloud Functions

Spark plan has no Cloud Functions (Blaze-only). So multiplayer must be **client-authoritative with one elected host**:
- The host device (session creator) runs the actual `DmTurnEngine` (Phase 03) locally against its own Gemma model.
- Non-host devices send **player actions** to Firestore; the host listens, feeds them into its local DM engine, and writes the resulting `CampaignState` deltas back to Firestore.
- All clients (including host) render from the Firestore-synced `CampaignState`, so everyone sees the same world.
- Trade-off to state plainly: this means non-host players' experience depends on the host staying connected and their device doing the AI inference. If the host disconnects, the session pauses (see reconnection handling below) — there is no serverless fallback DM on Spark plan. This is an accepted MVP limitation, not an oversight.

## Deliverables

1. Firebase Auth: anonymous auth for MVP (no email/password friction for a "play with friends" flow); upgradeable later to real accounts.
2. Firestore schema for sessions, players, and synced campaign state.
3. Session lifecycle: create session (host), join via short code, leave, host migration/pause-on-disconnect handling.
4. Firestore security rules restricting read/write to session participants only.
5. Client-side quota awareness: batch writes, debounce frequent state changes, warn (in Settings/dev tools) if approaching Spark's daily read/write limits.

## Tasks

### 1. Firebase Auth (anonymous)
- Enable Anonymous provider in Firebase console/via `firebase` MCP tools.
- On first multiplayer interaction, call `FirebaseAuth.instance.signInAnonymously()` if not already signed in. Store the resulting `uid` as the player's stable identity for session membership.

### 2. Firestore schema
```
sessions/{sessionId}
  - hostUid: string
  - joinCode: string (6-char, human-shareable)
  - status: "lobby" | "active" | "paused" | "ended"
  - createdAt: timestamp
  - campaignSeed: map (from Phase 03's CampaignSeed)

sessions/{sessionId}/players/{uid}
  - displayName: string
  - characterId: string (references the player's Character doc)
  - connectionStatus: "online" | "offline"
  - lastSeen: timestamp

sessions/{sessionId}/state/current  (single doc, the synced CampaignState)
  - currentSceneDescription, party[], questLog[], worldFlags, currentMapId, partyPosition, visitedTiles (Phase 03/05 schema, Firestore-serializable form)

sessions/{sessionId}/actions/{actionId}  (append-only, host consumes and can delete/archive after processing to manage the 1GiB storage cap)
  - fromUid, actionText, submittedAt, processed: bool
```
- Keep `state/current` as a **single document** (not one doc per field) to minimize read count — Spark's 50K reads/day is the binding constraint for a chatty game loop, so batch state into one doc that all clients listen to with a single `onSnapshot`.

### 3. Session lifecycle
- **Create**: host writes `sessions/{id}` with a generated join code, creates their own `players/{uid}` doc, status `lobby`.
- **Join**: non-host queries `sessions` where `joinCode == enteredCode` and `status == "lobby"`, then writes their own `players/{uid}` doc.
- **Start**: host transitions status to `active` once all players have picked characters (Phase 04 flow, but writing to the session's player doc instead of local-only).
- **Host disconnect handling**: use Firestore's presence pattern (a `lastSeen` heartbeat written every N seconds, checked client-side since Spark has no server-side presence/Cloud Functions) — if the host's `lastSeen` is stale beyond a threshold, all clients show "host disconnected, waiting to reconnect" and the session status flips to `paused`. No auto host-migration for MVP (a paused session that resumes when the host returns is a scoped-down, achievable target; host migration mid-session is a real distributed-systems problem — explicitly deferred, not silently dropped).
- **Leave/end**: player leaving marks their player doc `connectionStatus: offline`; host ending the session sets `status: ended` and clients navigate out.

### 4. Client sync layer
- `SessionRepository` wrapping Firestore streams: `Stream<SessionDoc> watchSession(id)`, `Stream<CampaignStateDoc> watchState(id)`, `Future<void> submitAction(id, actionText)`, `Future<void> pushStateUpdate(id, state)` (host-only).
- Non-host `Play` screen: player types/selects an action → `submitAction` writes to `actions/`, UI shows "waiting for DM..." until `state/current` updates.
- Host `Play` screen: listens to `actions/` where `processed == false`, feeds each into local `DmTurnEngine` (Phase 03) in submission order, writes the updated state, marks the action `processed: true`.

### 5. Security rules
```
match /sessions/{sessionId} {
  allow read: if request.auth != null && exists(/databases/$(database)/documents/sessions/$(sessionId)/players/$(request.auth.uid));
  allow create: if request.auth != null;
  match /players/{uid} {
    allow read: if request.auth != null;
    allow write: if request.auth.uid == uid;
  }
  match /state/{doc} {
    allow read: if request.auth != null;
    allow write: if request.auth.uid == resource.data.hostUid || request.auth.uid == get(/databases/$(database)/documents/sessions/$(sessionId)).data.hostUid;
  }
  match /actions/{actionId} {
    allow create: if request.auth != null;
    allow read, update: if request.auth.uid == get(/databases/$(database)/documents/sessions/$(sessionId)).data.hostUid;
  }
}
```
- Deploy via `firebase_deploy` (MCP) or `firebase deploy --only firestore:rules`.
- Write a small rules-unit-test suite using the Firebase emulator (`firebase emulators:start`) before deploying to production rules.

### 6. Spark quota awareness
- Debounce `partyPosition` updates (movement) client-side — don't write to Firestore on every pixel of drag, only on completed tile-move.
- Cap `actions/` collection growth: host deletes/archives processed actions older than the current session (or the whole subcollection on session end) to stay under the 1GiB storage cap across many sessions.
- Add a debug counter (visible in the `/debug` route from Phase 02) tracking reads/writes this session, to catch runaway listeners during development before they become a production quota surprise.

## Acceptance criteria

- [ ] Two physical devices can create/join a session via join code and see each other in the lobby.
- [ ] A non-host player's submitted action results in host-generated narration appearing on both devices.
- [ ] Killing the host app mid-session flips other clients to "paused/waiting," and resuming the host app resumes play without data loss.
- [ ] Firestore security rules deployed and verified with the emulator test suite (a non-participant cannot read/write a session's docs).
- [ ] A 6-player, 1-hour test session stays comfortably under Spark's daily read/write limits (measured via the debug counter).

## Key files

- `lib/data/remote/session_repository.dart`
- `lib/domain/session.dart`, `lib/domain/session_player.dart`
- `firestore.rules`
- `lib/features/multiplayer/lobby_screen.dart`, `join_screen.dart`, `multiplayer_play_screen.dart`
