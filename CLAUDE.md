# CLAUDE.md

Native iOS client for Mercury (`../mercury`). See `docs/ARCHITECTURE.md` for structure and
`docs/adr/` for decisions. The backend's contract source is `../mercury/docs/api/openapi.yaml`;
its human guide is `../mercury/docs/API.md`.

## Commands

```bash
xcodegen generate        # REQUIRED after cloning and after every project.yml change
swift format lint --strict --recursive Mercury MercuryTests MercuryUITests
swift format --in-place --recursive Mercury MercuryTests MercuryUITests

# Build + hermetic unit tests (what CI runs)
xcodebuild -project Mercury.xcodeproj -scheme Mercury \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build build test

# UI smoke against a LIVE backend (local-only, not in CI)
TEST_RUNNER_MERCURY_BASE_URL=http://localhost:3000 \
xcodebuild -project Mercury.xcodeproj -scheme MercurySmoke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build test
```

Files are included in targets by directory (`Mercury/`, `MercuryTests/`, `MercuryUITests/`) —
adding a file needs no project edit, just `xcodegen generate`.

## Backend for development

In `../mercury` (see its README; Homebrew Postgres works, Docker is not required):

```bash
bun install && bun run db:migrate && bun run db:seed
bun run dev        # http://localhost:3000 — matches Config/Debug.xcconfig
```

If :3000 is occupied by a stale server (symptom: `/api/v1/me` returns a 307 redirect instead of
a 401 JSON envelope), restart it or run on another port with env overrides:
`DATABASE_URL=… BETTER_AUTH_URL=http://localhost:3001 PORT=3001 bun run dev`, then point the app
at it via the Profile tab's Debug override or `TEST_RUNNER_MERCURY_BASE_URL` for the smoke.

## Fixtures = the API contract

`MercuryTests/Fixtures/*.json` are captured from a live server. **After any backend API change**:

```bash
BASE_URL=http://localhost:3000 scripts/refresh-fixtures.sh
git diff MercuryTests/Fixtures/   # a diff means the contract moved — update models to match
```

Test assertions must target capture-deterministic invariants (toeic onboarding, fresh account,
seeded content shape) — never emails, timestamps, or random quiz values.

## Rules that prevent subtle breakage

- **Never re-enable cookies** on the URLSession (`APIClient.makeURLSessionConfiguration`): a
  replayed better-auth cookie without an `Origin` header fails CSRF. Bearer-only; token lives in
  the Keychain. See `docs/adr/0004`.
- **Don't add `@MainActor` annotations** — the whole app target is MainActor by default
  (`project.yml`; see `docs/adr/0003`). `MercuryUITests` is the only nonisolated target.
- Server error messages are English; user-facing errors go through
  `APIError.localizedMessage(for:)`. New UI strings need zh-Hans entries in
  `Mercury/Support/Localizable.xcstrings` (plain JSON — the exact keys, including `%lld`/`%@`
  specifiers, come from building with `SWIFT_EMIT_LOC_STRINGS` and reading the `.stringsdata`
  under DerivedData).
- Full-height custom screens must scroll: at accessibility text sizes a fixed VStack overflows
  and its buttons become untappable (this actually broke onboarding once).

## UI-test hooks (DEBUG builds only)

| Launch environment | Effect |
|---|---|
| `MERCURY_BASE_URL_OVERRIDE` | points the app at another server |
| `MERCURY_RESET_SESSION=1` | clears the Keychain token at startup |
| `MERCURY_DISABLE_ANIMATIONS=1` | `UIView.setAnimationsEnabled(false)` — animations lose synthesized taps |

The smoke also dismisses iOS's cross-process "Save Password?" sheet (hosted by
SafariViewService) and iOS's "Use Strong Password?" sheet is avoided by not using `.newPassword`
content type on sign-up.

## Gotchas that cost time once

- Xcode refuses **all** simulator destinations until the iOS runtime matching its SDK is
  installed ("iOS X.Y is not installed"); older runtimes alone don't satisfy it, and `actool`
  fails thinned asset builds without it. CI pins the `macos-26` image for this reason.
- `simctl` can't tap; drive flows with the smoke test, verify side effects with `curl`/psql, and
  read failure-time UI from the `.xcresult` (`xcrun xcresulttool export attachments`) — the "App
  UI hierarchy" attachment shows overlaying system sheets that screenshots taken later miss.
- `//` starts a comment in xcconfig — hence `http:/$()/localhost:3000` in `Config/Debug.xcconfig`.
