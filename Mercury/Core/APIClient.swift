import Foundation

/// Seam between the API clients and URLSession so tests can stub the wire.
protocol HTTPTransport: AnyObject {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, http)
    }
}

enum JSONCoding {
    /// The server serializes JS `Date`s as ISO-8601 with fractional seconds
    /// (e.g. `2026-07-07T01:24:38.212Z`), which Foundation's stock `.iso8601`
    /// strategy rejects.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(string, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unparseable ISO-8601 date: \(string)"
                ))
        }
        return decoder
    }
}

protocol MercuryAPI: AnyObject {
    func me() async throws -> MeResponse
    func updateSettings(track: Track) async throws -> UserSettings
    func dashboard() async throws -> DashboardResponse
    func vocabOverview() async throws -> VocabOverview
    func studyQueue() async throws -> [StudyCard]
    func grade(wordId: String, grade: Grade) async throws -> Int
    func quiz() async throws -> QuizResponse
    func submitQuiz(track: Track, answers: [String: String]) async throws -> QuizResult
}

final class APIClient: MercuryAPI {
    private let baseURL: URL
    private let tokenStore: any TokenStore
    private let transport: any HTTPTransport
    private let decoder = JSONCoding.makeDecoder()

    /// Fired on any 401 so the session layer can purge the token and
    /// return to the login screen.
    var onUnauthorized: (() -> Void)?

    init(baseURL: URL, tokenStore: any TokenStore, transport: (any HTTPTransport)? = nil) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.transport =
            transport
            ?? URLSessionTransport(session: URLSession(configuration: APIClient.makeURLSessionConfiguration()))
    }

    /// Bearer-only: better-auth also sets a session cookie, and replaying it
    /// without an `Origin` header trips its CSRF check. Never store cookies.
    static func makeURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 15
        return configuration
    }

    // MARK: - MercuryAPI

    func me() async throws -> MeResponse {
        try await send(MeResponse.self, method: "GET", path: "/api/v1/me")
    }

    func updateSettings(track: Track) async throws -> UserSettings {
        struct Body: Encodable { let track: Track }
        let response = try await send(
            SettingsResponse.self, method: "PUT", path: "/api/v1/me/settings",
            body: Body(track: track)
        )
        return response.settings
    }

    func dashboard() async throws -> DashboardResponse {
        try await send(DashboardResponse.self, method: "GET", path: "/api/v1/dashboard")
    }

    func vocabOverview() async throws -> VocabOverview {
        try await send(VocabOverview.self, method: "GET", path: "/api/v1/vocab/overview")
    }

    func studyQueue() async throws -> [StudyCard] {
        try await send(StudyQueue.self, method: "GET", path: "/api/v1/vocab/study-queue").cards
    }

    func grade(wordId: String, grade: Grade) async throws -> Int {
        struct Body: Encodable {
            let wordId: String
            let grade: Int
        }
        let response = try await send(
            GradeResponse.self, method: "POST", path: "/api/v1/vocab/grade",
            body: Body(wordId: wordId, grade: grade.rawValue)
        )
        return response.intervalDays
    }

    func quiz() async throws -> QuizResponse {
        try await send(QuizResponse.self, method: "GET", path: "/api/v1/vocab/quiz")
    }

    func submitQuiz(track: Track, answers: [String: String]) async throws -> QuizResult {
        struct Body: Encodable {
            let track: Track
            let answers: [String: String]
        }
        return try await send(
            QuizResult.self, method: "POST", path: "/api/v1/vocab/quiz",
            body: Body(track: track, answers: answers)
        )
    }

    // MARK: - Plumbing

    private func send<T: Decodable>(
        _ type: T.Type, method: String, path: String, body: (any Encodable)? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = tokenStore.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(underlying: error)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw serverError(status: response.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }

    private func serverError(status: Int, data: Data) -> APIError {
        if status == 401 {
            onUnauthorized?()
        }
        guard let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) else {
            return .invalidResponse
        }
        return .server(
            status: status,
            code: APIErrorCode(rawValue: envelope.error.code),
            message: envelope.error.message
        )
    }
}
