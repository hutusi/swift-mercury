# ADR 0003: Swift 6 language mode with default MainActor isolation

**Status:** Accepted (2026-07)

## Context

Swift 6 strict concurrency in its default form imposes heavy `Sendable`/isolation ceremony that
buys little in a small UI app where essentially everything belongs on the main thread anyway.
Apple's recommended configuration for app targets (Xcode 26) is full data-race safety with
main-actor-by-default semantics.

## Decision

**`SWIFT_VERSION = 6.0` + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` +
`SWIFT_APPROACHABLE_CONCURRENCY = YES` for all targets except `MercuryUITests`.**

Every type — models, `APIClient`, `SessionModel`, view models — is implicitly `@MainActor`.
Networking never blocks the main thread because `URLSession.data(for:)` is async; with
approachable concurrency it resumes on the caller's actor. No `Sendable` conformances, no actor
hops, no `nonisolated` annotations in app code.

The UI test target overrides back to `nonisolated` because `XCTestCase` subclasses must override
nonisolated initializers, which default-MainActor breaks; individual test methods opt into
`@MainActor` instead.

## Consequences

- Data-race safety is fully checked by the compiler with near-zero annotation burden.
- Anything genuinely needing off-main execution must be explicitly `nonisolated` — none exists
  yet. Heavy work added later (e.g. an offline sync engine, ADR 0005) will need deliberate
  isolation design rather than inheriting the default.
- Reviewers should not "fix" missing `@MainActor` annotations — they are the project default
  (this misled an automated review on PR #1).
