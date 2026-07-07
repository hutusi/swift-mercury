import Foundation

/// Talks to better-auth's `/api/auth/*` endpoints, which do not use the
/// `/api/v1` error envelope. The session token arrives in the
/// `set-auth-token` response header (also mirrored in the body).
final class AuthService {
    private struct AuthErrorBody: Decodable {
        let message: String?
        let code: String?
    }

    private struct TokenBody: Decodable {
        let token: String?
    }

    private let baseURL: URL
    private let transport: any HTTPTransport

    init(baseURL: URL, transport: (any HTTPTransport)? = nil) {
        self.baseURL = baseURL
        self.transport =
            transport
            ?? URLSessionTransport(session: URLSession(configuration: APIClient.makeURLSessionConfiguration()))
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        struct Body: Encodable {
            let name: String
            let email: String
            let password: String
        }
        return try await authenticate(
            path: "/api/auth/sign-up/email",
            body: Body(name: name, email: email, password: password)
        )
    }

    func signIn(email: String, password: String) async throws -> String {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return try await authenticate(
            path: "/api/auth/sign-in/email",
            body: Body(email: email, password: password)
        )
    }

    /// Best-effort server-side revocation; the caller purges the local token
    /// regardless of the outcome.
    func signOut(token: String) async {
        var request = makeRequest(path: "/api/auth/sign-out")
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await transport.send(request)
    }

    private func authenticate(path: String, body: any Encodable) async throws -> String {
        var request = makeRequest(path: path)
        request.httpBody = try JSONEncoder().encode(body)

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
            let body = try? JSONDecoder().decode(AuthErrorBody.self, from: data)
            // better-auth messages are English-only; localize the code we know.
            let message: String
            if body?.code == "INVALID_EMAIL_OR_PASSWORD" {
                message = String(localized: "Invalid email or password.")
            } else {
                message = body?.message ?? String(localized: "Authentication failed.")
            }
            throw APIError.authFailed(message: message)
        }

        if let token = response.value(forHTTPHeaderField: "set-auth-token"), !token.isEmpty {
            return token
        }
        if let token = try? JSONDecoder().decode(TokenBody.self, from: data).token, !token.isEmpty {
            return token
        }
        throw APIError.invalidResponse
    }

    private func makeRequest(path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
