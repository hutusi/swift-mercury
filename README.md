# swift-mercury

[![CI](https://github.com/hutusi/swift-mercury/actions/workflows/ci.yml/badge.svg)](https://github.com/hutusi/swift-mercury/actions/workflows/ci.yml)

Native iOS client for [Mercury](https://github.com/hutusi/mercury), a bilingual
(简体中文 / English) English-learning app for TOEIC, IELTS, and Business English.

This MVP covers auth, onboarding, the dashboard, and the full vocabulary
feature (SM-2 spaced-repetition flashcards and self-check quizzes) against
Mercury's `/api/v1` REST API. The UI is bilingual — Simplified Chinese when
the system locale is zh-Hans, English otherwise. Reading/listening drills,
the mistakes notebook, mock exams, and writing/speaking are later phases.

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

SwiftUI + `@Observable` view models, Swift 6 with default MainActor isolation,
zero third-party dependencies, bearer-only cookie-free auth with the token in
the Keychain. The long version lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md);
decisions and their trade-offs are recorded in [docs/adr/](docs/adr/).
Day-to-day commands and contribution gotchas: [CLAUDE.md](CLAUDE.md).

## Tests

Unit tests (`MercuryTests`) run with the scheme's test action and are hermetic
(stubbed transport, no network). DTO tests decode JSON fixtures captured from
a live server — refresh them after backend API changes with
`scripts/refresh-fixtures.sh`. The UI smoke test (`MercuryUITests`) drives
register → onboard → study against a live backend:

```bash
TEST_RUNNER_MERCURY_BASE_URL=http://localhost:3000 \
xcodebuild -project Mercury.xcodeproj -scheme MercurySmoke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build test
```
