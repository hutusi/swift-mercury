# swift-mercury

Native iOS client for [Mercury](https://github.com/hutusi/mercury), a bilingual
(简体中文 / English) English-learning app for TOEIC, IELTS, and Business English.

This MVP covers auth, onboarding, the dashboard, and the full vocabulary
feature (SM-2 spaced-repetition flashcards and self-check quizzes) against
Mercury's `/api/v1` REST API. Reading/listening drills, the mistakes notebook,
mock exams, and writing/speaking are later phases.

## Requirements

- Xcode 26+ with an iOS 18+ simulator runtime
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A running Mercury backend (see below)

## Getting started

```bash
xcodegen generate          # creates Mercury.xcodeproj (gitignored)
open Mercury.xcodeproj
```

Or from the CLI:

```bash
xcodebuild -project Mercury.xcodeproj -scheme Mercury \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build build test
```

## Backend

The Debug build points at `http://localhost:3000` (see `Config/Debug.xcconfig`).
In the Mercury repo:

```bash
docker compose up -d       # or any local Postgres; see docker-compose.yml
bun install
bun run db:migrate && bun run db:seed
bun run dev
```

To target a different server without editing the config, use the
**Developer: Server Override** field in the app's Profile tab (Debug builds
only), or launch with `-debug.baseURLOverride http://host:port`.

## Architecture

- SwiftUI + `@Observable` view models, Swift 6 language mode with default
  MainActor isolation. No third-party dependencies.
- `SessionModel` (Features/Session) drives the root switch:
  loading → login → onboarding → main tabs. Any 401 lands back on login.
- `APIClient` (Core) is a hand-written URLSession + Codable client for
  `/api/v1`. The contract source is Mercury's `docs/api/openapi.yaml`; JSON
  fixtures in `MercuryTests/Fixtures/` are captured verbatim from a live
  server and pin the models to the real wire format.
- Auth is bearer-token only (better-auth): the token arrives in the
  `set-auth-token` response header and lives in the Keychain. The URLSession
  is configured to never store cookies — a replayed session cookie without an
  `Origin` header trips better-auth's CSRF check.

## Tests

Unit tests (`MercuryTests`) run with the scheme's test action and are hermetic
(stubbed transport, no network). The UI smoke test (`MercuryUITests`) drives
register → onboard → study against a live backend:

```bash
TEST_RUNNER_MERCURY_BASE_URL=http://localhost:3000 \
xcodebuild -project Mercury.xcodeproj -scheme MercurySmoke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build test
```
