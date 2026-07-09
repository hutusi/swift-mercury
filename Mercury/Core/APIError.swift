import Foundation

/// Error codes from the `/api/v1` error envelope. String-backed so unknown
/// future codes still surface instead of failing to decode.
struct APIErrorCode: RawRepresentable, Equatable, Hashable {
    let rawValue: String

    static let unauthorized = APIErrorCode(rawValue: "unauthorized")
    static let onboardingRequired = APIErrorCode(rawValue: "onboarding_required")
    static let integrity = APIErrorCode(rawValue: "integrity")
    static let notFound = APIErrorCode(rawValue: "not_found")
    static let validationFailed = APIErrorCode(rawValue: "validation_failed")
    static let invalidJSON = APIErrorCode(rawValue: "invalid_json")
    static let aiUnavailable = APIErrorCode(rawValue: "ai_unavailable")
    static let internalError = APIErrorCode(rawValue: "internal")
}

enum APIError: Error {
    /// A `/api/v1` response with the standard `{"error": {...}}` envelope.
    case server(status: Int, code: APIErrorCode, message: String)
    /// A better-auth failure from `/api/auth/*` (not enveloped).
    case authFailed(message: String)
    case transport(underlying: any Error)
    case decoding(underlying: any Error)
    case invalidResponse
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .server(_, let code, let message): APIError.localizedMessage(for: code) ?? message
        case .authFailed(let message): message
        case .transport: String(localized: "Could not reach the server. Check your connection.")
        case .decoding: String(localized: "The server sent an unexpected response.")
        case .invalidResponse: String(localized: "The server sent an unexpected response.")
        }
    }

    /// Server error messages arrive in English regardless of the user's
    /// locale, so known codes map to localized client copy; unknown codes
    /// fall back to the raw server message.
    static func localizedMessage(for code: APIErrorCode) -> String? {
        switch code {
        case .unauthorized: String(localized: "Please sign in again.")
        case .onboardingRequired: String(localized: "Pick a learning track first.")
        case .validationFailed: String(localized: "That input wasn't accepted. Check it and try again.")
        case .notFound: String(localized: "That content is no longer available.")
        case .integrity: String(localized: "That action isn't available right now.")
        case .aiUnavailable: String(localized: "AI feedback is temporarily unavailable. Try again later.")
        case .internalError: String(localized: "Something went wrong on the server. Try again.")
        default: nil
        }
    }
}

struct ErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
    }

    let error: Payload
}
