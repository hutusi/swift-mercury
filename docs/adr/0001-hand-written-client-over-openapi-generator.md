# ADR 0001: Hand-written API client over swift-openapi-generator

**Status:** Accepted (2026-07)

## Context

Mercury publishes an OpenAPI 3.1 contract (`mercury/docs/api/openapi.yaml`) explicitly designed
to be consumable by `swift-openapi-generator`, and drift between spec and server is guarded by a
coverage test on the backend. The obvious move was to generate the Swift client.

## Decision

**A small hand-written URLSession + Codable client (`Mercury/Core/APIClient.swift`), with the
OpenAPI document kept as the contract reference, not as build input.**

- The API surface is ~30 endpoints of plain JSON with no streaming or pagination. Generated
  clients produce deeply nested types (`Operations.getVocabOverview.Output.Ok.Body…`) that get
  wrapped in hand-written façades anyway; here the façade *is* the client.
- Contract fidelity comes from a different mechanism: JSON fixtures captured verbatim from a live
  server (`scripts/refresh-fixtures.sh`) pin the `Decodable` models to the real wire format in
  unit tests. This caught a real gap on day one — the spec's `VocabWord` schema is a subset of
  what the server actually returns.
- Zero build-time dependencies keeps the toolchain xcodegen + Xcode only.

## Consequences

- New endpoints are added by hand (model + method + fixture). Acceptable at this API's size; the
  drills phase should revisit if the surface triples.
- Spec/client drift is caught at fixture-refresh time rather than at code-generation time, so
  refreshing fixtures after backend API changes is part of the workflow (documented in CLAUDE.md).
