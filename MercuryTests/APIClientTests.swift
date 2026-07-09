import Foundation
import Testing

@testable import Mercury

struct APIClientTests {
    private let baseURL = URL(string: "http://localhost:3000")!

    private func makeClient(
        token: String? = nil,
        responder: @escaping (URLRequest) throws -> (Data, HTTPURLResponse)
    ) -> (APIClient, StubTransport) {
        let transport = StubTransport(responder: responder)
        let client = APIClient(
            baseURL: baseURL,
            tokenStore: InMemoryTokenStore(token: token),
            transport: transport
        )
        return (client, transport)
    }

    @Test func sendsBearerTokenWhenPresent() async throws {
        let body = try Fixtures.data("me")
        let (client, transport) = makeClient(token: "tok-123") { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        _ = try await client.me()

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok-123")
        #expect(request.url?.path() == "/api/v1/me")
        #expect(request.httpMethod == "GET")
    }

    @Test func omitsAuthorizationWithoutToken() async throws {
        let body = try Fixtures.data("me")
        let (client, transport) = makeClient { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        _ = try await client.me()

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func mapsErrorEnvelopeAndFiresUnauthorizedCallback() async throws {
        let body = try Fixtures.data("error-unauthorized")
        let (client, _) = makeClient { request in
            (body, makeHTTPResponse(url: request.url!, status: 401))
        }
        var unauthorizedFired = false
        client.onUnauthorized = { unauthorizedFired = true }

        await #expect {
            _ = try await client.dashboard()
        } throws: { error in
            guard case .server(let status, let code, _) = error as? APIError else { return false }
            return status == 401 && code == .unauthorized
        }
        #expect(unauthorizedFired)
    }

    @Test func mapsValidationErrorWithoutFiringUnauthorized() async throws {
        let body = try Fixtures.data("error-validation")
        let (client, _) = makeClient(token: "tok") { request in
            (body, makeHTTPResponse(url: request.url!, status: 422))
        }
        var unauthorizedFired = false
        client.onUnauthorized = { unauthorizedFired = true }

        await #expect {
            _ = try await client.updateSettings(track: .toeic)
        } throws: { error in
            guard case .server(_, let code, _) = error as? APIError else { return false }
            return code == .validationFailed
        }
        #expect(!unauthorizedFired)
    }

    @Test func nonEnvelopeErrorBodyBecomesInvalidResponse() async throws {
        let (client, _) = makeClient(token: "tok") { request in
            (Data("<html>bad gateway</html>".utf8), makeHTTPResponse(url: request.url!, status: 502))
        }

        await #expect {
            _ = try await client.me()
        } throws: { error in
            guard case .invalidResponse = error as? APIError else { return false }
            return true
        }
    }

    @Test func gradeEncodesServerContractPayload() async throws {
        let body = try Fixtures.data("grade")
        let (client, transport) = makeClient(token: "tok") { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        let intervalDays = try await client.grade(wordId: "toeic-w-001", grade: .good)

        #expect(intervalDays == 1)
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/api/v1/vocab/grade")
        let payload = try #require(request.bodyJSON)
        #expect(payload["wordId"] as? String == "toeic-w-001")
        #expect(payload["grade"] as? Int == 4)
    }

    @Test func submitQuizEncodesTrackAndAnswers() async throws {
        let body = try Fixtures.data("quiz-result")
        let (client, transport) = makeClient(token: "tok") { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        let result = try await client.submitQuiz(
            track: .toeic,
            answers: ["toeic-w-068": "toeic-w-025"]
        )

        #expect(result.score == result.correctWordIds.count)
        let payload = try #require(transport.requests.first?.bodyJSON)
        #expect(payload["track"] as? String == "toeic")
        let answers = try #require(payload["answers"] as? [String: String])
        #expect(answers == ["toeic-w-068": "toeic-w-025"])
    }

    @Test func updateSettingsUnwrapsSettingsEnvelope() async throws {
        let body = try Fixtures.data("settings")
        let (client, transport) = makeClient(token: "tok") { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        let settings = try await client.updateSettings(track: .toeic)

        #expect(settings.activeTrack == .toeic)
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.bodyJSON?["track"] as? String == "toeic")
    }

    @Test func studyQueueUnwrapsCards() async throws {
        let body = try Fixtures.data("study-queue")
        let (client, _) = makeClient(token: "tok") { request in
            (body, makeHTTPResponse(url: request.url!, status: 200))
        }

        let cards = try await client.studyQueue()

        #expect(!cards.isEmpty)
        #expect(cards.allSatisfy { $0.wordId == $0.word.id })
    }

    @Test func sessionConfigurationNeverTouchesCookies() {
        let configuration = APIClient.makeURLSessionConfiguration()
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.httpCookieAcceptPolicy == .never)
    }
}
