# ADR 0005: Offline study deferred (deliberately)

**Status:** Accepted (2026-07) — records a *deferral*, not an implementation

## Context

The target user studies on commutes; subway connectivity makes offline flashcard review the
single highest-value feature the app doesn't have. Today every screen requires the network and
fails to an error-with-retry state. The backend was designed with this future in mind: the SM-2
grade endpoint (`POST /vocab/grade`) is an idempotent-per-review, retry-safe transaction, so a
client-side queue can replay grades without double-advancing scheduling state.

## Decision

**Ship the MVP online-only and give offline its own design pass later, rather than bolting a
cache onto the quality branch.**

The intended shape, sketched so future work starts aligned:

- Local store (likely SwiftData) caching the track's vocab words and the current study queue.
- A durable grade queue: grades apply to the local queue immediately and replay to
  `POST /vocab/grade` in order when connectivity returns; the server transaction's retry safety
  is the conflict story for the common case.
- Read models (dashboard, overview) stay server-authoritative — show stale data with a
  freshness indicator, never recompute streaks client-side (server timezone owns streaks).
- Exams, writing, speaking stay online-only by design (server-issued deadlines, AI grading).

## Consequences

- Airplane-mode UX is currently an error screen; acceptable for MVP, tracked as the top
  post-drills feature.
- Nothing in the current architecture blocks the sketch above: `MercuryAPI` is a protocol, so a
  caching decorator can wrap the live client without touching view models.
