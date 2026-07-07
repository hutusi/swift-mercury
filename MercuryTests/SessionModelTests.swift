import Foundation
import Testing

@testable import Mercury

struct SessionModelTests {
    private func makeSession(
        token: String? = nil,
        configure: (MockAPI) -> Void = { _ in }
    ) -> (SessionModel, MockAPI, InMemoryTokenStore) {
        let api = MockAPI()
        configure(api)
        let tokenStore = InMemoryTokenStore(token: token)
        // AuthService is only exercised via sign-in/up tests, which stub the wire.
        let auth = AuthService(
            baseURL: URL(string: "http://localhost:3000")!,
            transport: StubTransport { request in
                (
                    Data("{\"token\":\"fresh-token\"}".utf8),
                    makeHTTPResponse(url: request.url!, status: 200, headers: ["set-auth-token": "fresh-token"])
                )
            }
        )
        let session = SessionModel(api: api, auth: auth, tokenStore: tokenStore)
        return (session, api, tokenStore)
    }

    @Test func bootstrapWithoutTokenIsSignedOut() async {
        let (session, _, _) = makeSession()

        await session.bootstrap()

        #expect(session.phase == .signedOut)
    }

    @Test func bootstrapWithoutSettingsRequiresOnboarding() async {
        let (session, _, _) = makeSession(token: "tok") { api in
            api.meHandler = { .fixture(settings: nil) }
        }

        await session.bootstrap()

        #expect(session.phase == .onboardingRequired)
        #expect(session.me != nil)
    }

    @Test func bootstrapWithSettingsIsReady() async {
        let (session, _, _) = makeSession(token: "tok") { api in
            api.meHandler = { .fixture() }
        }

        await session.bootstrap()

        #expect(session.phase == .ready)
        #expect(session.me?.settings?.activeTrack == .toeic)
    }

    @Test func bootstrapWith401PurgesTokenAndSignsOut() async {
        let (session, _, tokenStore) = makeSession(token: "stale") { api in
            api.meHandler = {
                throw APIError.server(status: 401, code: .unauthorized, message: "Authentication required")
            }
        }

        await session.bootstrap()

        #expect(session.phase == .signedOut)
        #expect(tokenStore.load() == nil)
    }

    @Test func bootstrapTransportErrorIsFailedNotSignedOut() async {
        let (session, _, tokenStore) = makeSession(token: "tok") { api in
            api.meHandler = {
                throw APIError.transport(underlying: URLError(.cannotConnectToHost))
            }
        }

        await session.bootstrap()

        guard case .failed = session.phase else {
            Issue.record("expected .failed, got \(session.phase)")
            return
        }
        #expect(tokenStore.load() == "tok")
    }

    @Test func signInStoresTokenAndLoadsMe() async throws {
        let (session, api, tokenStore) = makeSession()
        api.meHandler = { .fixture() }

        try await session.signIn(email: "a@b.com", password: "password123")

        #expect(tokenStore.load() == "fresh-token")
        #expect(session.phase == .ready)
    }

    @Test func completeOnboardingUpdatesSettingsAndPhase() async throws {
        let (session, api, _) = makeSession(token: "tok") { api in
            api.meHandler = { .fixture(settings: nil) }
        }
        api.updateSettingsHandler = { track in .fixture(track: track) }
        await session.bootstrap()

        try await session.completeOnboarding(track: .ielts)

        #expect(session.phase == .ready)
        #expect(session.me?.settings?.activeTrack == .ielts)
    }

    @Test func signOutClearsTokenAndReturnsToLogin() async {
        let (session, api, tokenStore) = makeSession(token: "tok") { api in
            api.meHandler = { .fixture() }
        }
        _ = api
        await session.bootstrap()

        await session.signOut()

        #expect(session.phase == .signedOut)
        #expect(tokenStore.load() == nil)
        #expect(session.me == nil)
    }
}
