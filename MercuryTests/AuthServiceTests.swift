import Foundation
import Testing

@testable import Mercury

struct AuthServiceTests {
    private let baseURL = URL(string: "http://localhost:3000")!

    private func makeService(
        responder: @escaping (URLRequest) throws -> (Data, HTTPURLResponse)
    ) -> (AuthService, StubTransport) {
        let transport = StubTransport(responder: responder)
        return (AuthService(baseURL: baseURL, transport: transport), transport)
    }

    @Test func signInPrefersHeaderToken() async throws {
        let body = try Fixtures.data("signup-body")
        let (service, transport) = makeService { request in
            (
                body,
                makeHTTPResponse(
                    url: request.url!, status: 200,
                    headers: ["set-auth-token": "header-token"]
                )
            )
        }

        let token = try await service.signIn(email: "a@b.com", password: "password123")

        #expect(token == "header-token")
        let request = try #require(transport.requests.first)
        #expect(request.url?.path() == "/api/auth/sign-in/email")
        #expect(request.bodyJSON?["email"] as? String == "a@b.com")
    }

    @Test func signInFallsBackToBodyToken() async throws {
        // signup-body.json carries the token better-auth mirrors into the body;
        // the expected value is read from the fixture so recapture can't break this.
        let body = try Fixtures.data("signup-body")
        let raw = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let expected = try #require(raw?["token"] as? String)
        let (service, _) = makeService { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        let token = try await service.signIn(email: "a@b.com", password: "password123")

        #expect(token == expected)
    }

    @Test func signUpSendsNameEmailPassword() async throws {
        let body = try Fixtures.data("signup-body")
        let (service, transport) = makeService { request in
            (
                body,
                makeHTTPResponse(
                    url: request.url!, status: 200,
                    headers: ["set-auth-token": "t"]
                )
            )
        }

        _ = try await service.signUp(name: "iOS Fixture", email: "a@b.com", password: "password123")

        let request = try #require(transport.requests.first)
        #expect(request.url?.path() == "/api/auth/sign-up/email")
        let payload = try #require(request.bodyJSON)
        #expect(payload["name"] as? String == "iOS Fixture")
        #expect(payload["email"] as? String == "a@b.com")
        #expect(payload["password"] as? String == "password123")
    }

    @Test func failedSignInSurfacesBetterAuthMessage() async throws {
        let body = try Fixtures.data("auth-error")
        let (service, _) = makeService { request in
            (body, makeHTTPResponse(url: request.url!, status: 401))
        }

        await #expect {
            _ = try await service.signIn(email: "a@b.com", password: "wrong")
        } throws: { error in
            guard case .authFailed(let message) = error as? APIError else { return false }
            return message == "Invalid email or password"
        }
    }

    @Test func successWithoutAnyTokenIsInvalidResponse() async throws {
        let (service, _) = makeService { request in
            (Data("{}".utf8), makeHTTPResponse(url: request.url!, status: 200))
        }

        await #expect {
            _ = try await service.signIn(email: "a@b.com", password: "password123")
        } throws: { error in
            guard case .invalidResponse = error as? APIError else { return false }
            return true
        }
    }
}
