# ADR 0004: Cookie-free bearer authentication

**Status:** Accepted (2026-07)

## Context

Client counterpart of Mercury's
[ADR 0010](https://github.com/hutusi/mercury/blob/main/docs/adr/0010-http-api-v1-bearer-auth.md).
better-auth issues the session token in the `set-auth-token` response header on
sign-up/sign-in, **and** sets a session cookie on the same response. If a native client lets
URLSession store that cookie, later requests replay it without an `Origin` header and trip
better-auth's CSRF check (`MISSING_OR_NULL_ORIGIN`) — auth breaks in ways that look random.

## Decision

**Bearer-only, with cookies disabled at the URLSession layer, and the token in the Keychain.**

- `APIClient.makeURLSessionConfiguration()`: `.ephemeral` configuration with
  `httpCookieStorage = nil`, `httpShouldSetCookies = false`, `httpCookieAcceptPolicy = .never`.
  Both `APIClient` and `AuthService` build their sessions from it; a unit test pins the
  configuration so a refactor can't silently re-enable cookies.
- Token source: `set-auth-token` response header, with the body's `token` field as fallback
  (better-auth mirrors it). Stored via `KeychainTokenStore`
  (`kSecAttrAccessibleAfterFirstUnlock`), never in UserDefaults.
- Any 401 anywhere purges the token and returns to login (`APIClient.onUnauthorized` →
  `SessionModel.forceSignOut()`). Transport failures at bootstrap deliberately do *not* — a dead
  network must not log the user out.

## Consequences

- Sessions are opaque and server-revocable; sign-out is best-effort revocation + local purge.
- Auth endpoints (`/api/auth/*`) don't use the `/api/v1` error envelope; `AuthService` decodes
  better-auth's `{code, message}` shape separately.
- Sliding 30-day sessions mean an active user never re-authenticates; there is no refresh-token
  dance to implement.
